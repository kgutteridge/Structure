module Structure
  module InstanceMethods
    # Validate that the structure don't include itself
    def structure_exclude_self
      errors.add(:base, "#{self.class.name.humanize} cannot be a descendant of itself.") if ancestor_ids.include? self.internal_id
    end

    # Update descendants with new structure
    def update_descendants_with_new_structure
      # Skip this if callbacks are disabled
      unless structure_callbacks_disabled?
        # If node is not a new record and structure was updated and the new structure is sane ...
        if changed.include?(self.base_class.structure_column.to_s) && !new_record? && sane_structure?
          # ... for each descendant ...
          unscoped_descendants.each do |descendant|
            # ... replace old ancestry with new ancestry
            descendant.without_structure_callbacks do
              column = self.class.structure_column
              v = read_attribute(column)
              descendant.update_attribute(
                  column,
                  descendant.read_attribute(descendant.class.structure_column).gsub(
                      /^#{self.child_structure}/,
                      if v.blank? then
                        internal_id.to_s
                      else
                        "#{v}/#{internal_id}"
                      end
                  )
              )
            end
          end
        end
      end
    end

    # Apply orphan strategy
    def apply_orphan_strategy
      # Skip this if callbacks are disabled
      unless structure_callbacks_disabled?
        # If this isn't a new record ...
        unless new_record?
          # ...destroy all descendants if orphan strategy is destroy
          if self.base_class.orphan_strategy == :destroy
            unscoped_descendants.each do |descendant|
              descendant.without_structure_callbacks do
                descendant.destroy
              end
            end
          end
        end
      end
    end

    # The structure value for this record's children
    def child_structure
      # New records cannot have children
      raise Structure::StructureException.new('No child structure for new record. Save record before performing tree operations.') if new_record?
      v = "#{self.send "#{self.base_class.structure_column}_was"}"
      return internal_id.to_s if v.blank?
      v.split(',').map{|x| x + '/' + internal_id.to_s}.join(',')
    end

    # Ancestors = all nodes above but NOT including the current ID
    def ancestor_ids
      read_attribute(self.base_class.structure_column).to_s.split(%r|[,/]|).uniq.map { |internal_id| cast_primary_key(internal_id) }
    end

    def ancestor_conditions
      {self.base_class.primary_key => ancestor_ids}
    end

    def ancestors(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).where(ancestor_conditions)
    end

    # Path = all nodes above and INCLUDING the current node
    def path_ids
      ancestor_ids + [internal_id]
    end

    def path_conditions
      {self.base_class.primary_key => path_ids}
    end

    def path(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).where(path_conditions)
    end

    #lineage = all nodes that are parents of the current node + current node + all descendants of the current node in the tree
    def lineage_ids
      ancestor_ids + subtree_ids
    end

    def lineage_conditions
      {self.base_class.primary_key => lineage_ids}
    end

    def lineage(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).where(lineage_conditions)
    end

    def depth
      ancestor_ids.size # this is probably incorrect as it just counts the structure without regard to how layered
    end

    def cache_depth
      write_attribute self.base_class.depth_cache_column, depth
    end

    # Parent
    def parent=(parent)
      write_attribute(self.base_class.structure_column, if parent.blank? then
                                                         nil
                                                       else
                                                         parent.child_structure
                                                       end)
    end

    def parents=(new_parents)
       structure = if new_parents.nil?
                    nil
                  else
                    (new_parents.collect { |x| (self.base_class.find(x.internal_id).child_structure.split("/") - [self.internal_id.to_s]).join("/") }).join(",")
                  end
                  
       write_attribute(self.base_class.structure_column, structure)
    end


    def parent_id=(parent_id)
      self.parent = if parent_id.blank? then
                      nil
                    else
                      unscoped_find(parent_id)
                    end
    end

    # branches are the multiple parents of the current node
    def branches
      if ancestor_ids.empty? then
        nil
      else
        read_attribute(self.base_class.structure_column).to_s.split(',')
      end
    end

    # the immediate node ids of the parents of the current node
    def parent_ids
      if ancestor_ids.empty? then
        nil
      else
        branches.map { |branch| cast_primary_key(branch.split('/').last) }.uniq
      end
    end

    def parents
      if is_root? then
        nil
      else
        unscoped_find(parent_ids)
      end
    end

    def has_parent?
      !is_root?
    end

    # Root - the topmost SINGULAR node of the current tree
    def root_id
      if ancestor_ids.empty? then
        id
      else
        branches.first.split('/').first
      end
    end

    def root
      if root_id == internal_id then
        self
      else
        unscoped_find(root_id)
      end
    end

    def is_root?
      read_attribute(self.base_class.structure_column).blank?
    end


    # Descendants = all the nodes below and NOT including the current node
    def descendant_conditions
      column = "#{self.base_class.table_name}.#{self.base_class.structure_column}"
      lookup = if has_parent? then
                 "%/#{internal_id}"
               else
                 "#{internal_id}"
               end
      ["#{column} like ?
        or #{column} like ?
        or #{column} like ?
        or #{column} like ?
        or #{column} = ?", "#{lookup}", "#{lookup}/%", "#{lookup},%", ",#{internal_id}", "#{internal_id}"]
    end

    def descendants(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).where(descendant_conditions)
    end

    def descendant_ids(depth_options = {})
      id_selector(descendants(depth_options))
    end

    # Subtree = all nodes below the current node INCLUDING the current node in the list
    def subtree_conditions
      column = "#{self.base_class.table_name}.#{self.base_class.structure_column}"
      lookup = if has_parent? then
                 "%/#{internal_id}"
               else
                 "#{internal_id}"
               end
      ["#{column} like ?
        or #{column} like ?
        or #{column} like ?
        or #{column} like ?
        or #{column} = ?
        or #{self.base_class.table_name}.#{self.base_class.primary_key} = ?", "#{lookup}", "#{lookup}/%", "#{lookup},%", ",#{internal_id}", "#{internal_id}", "#{internal_id}"]
    end

    def subtree(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).where(subtree_conditions)
    end

    def subtree_ids(depth_options = {})
      id_selector(subtree(depth_options))
    end

    # Callback disabling
    def without_structure_callbacks
      @disable_structure_callbacks = true
      yield
      @disable_structure_callbacks = false
    end

    def structure_callbacks_disabled?
      !!@disable_structure_callbacks
    end

    private

    def id_selector(starting_point)
      starting_point.pluck(self.base_class.primary_key.to_sym)
    end

    def cast_primary_key(key)
      if primary_key_type == :string
        key
      else
        key.to_i
      end
    end

    def primary_key_type
      @primary_key_type ||= column_for_attribute(self.class.primary_key).type
    end

    def unscoped_descendants
      self.base_class.unscoped do
        self.base_class.where(descendant_conditions)
      end
    end

    # basically validates the structure but also applied if validation is
    # bypassed to determine if children should be affected
    def sane_structure?
      structure.nil? || (structure.to_s =~ Structure::STRUCTURE_PATTERN && !ancestor_ids.include?(self.internal_id))
    end

    def unscoped_find(internal_id)
      self.base_class.unscoped { self.base_class.find(internal_id) }
    end
  end
end
