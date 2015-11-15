module Structure
  module ClassMethods
    # Fetch tree node if necessary
    def to_node(object)
      if object.is_a?(self.base_class) then
        object
      else
        find(object)
      end
    end 
    
    # Scope on relative depth options
    def scope_depth(depth_options, depth)
      depth_options.inject(self.base_class) do |scope, option|
        scope_name, relative_depth = option
        if [:before_depth, :to_depth, :at_depth, :from_depth, :after_depth].include? scope_name
          scope.send scope_name, depth + relative_depth
        else
          raise Structure::StructureException.new("Unknown depth option: #{scope_name}.")
        end
      end
    end

    def orphan_strategy=(orphan_strategy)
      class_variable_set :@@orphan_strategy, :destroy 
    end
    
    # Arrangement
    def arrange(options = {})
      scope =
          if options[:order].nil?
            self.base_class.ordered_by_structure
          else
            self.base_class.ordered_by_structure_and options.delete(:order)
          end
      # Get all nodes ordered by ancestry and start sorting them into an empty hash
      arrange_nodes scope.all(options)
    end
    
    # Arrange array of nodes into a nested hash of the form 
    # {node => children}, where children = {} if the node has no children
    def arrange_nodes(nodes)
      # Get all nodes ordered by ancestry and start sorting them into an empty hash
      nodes.inject(ActiveSupport::OrderedHash.new) do |arranged_nodes, node|
        # Find the insertion point for that node by going through its ancestors
        node.ancestor_ids.inject(arranged_nodes) do |insertion_point, ancestor_id|
          insertion_point.each do |parent, children|
            # Change the insertion point to children if node is a descendant of this parent
            insertion_point = children if ancestor_id == parent.id
          end
          insertion_point
        end[node] = ActiveSupport::OrderedHash.new
        arranged_nodes
      end
    end
    
    # Pseudo-preordered array of nodes.  Children will always follow parents, 
    # but the ordering of nodes within a rank depends on their order in the 
    # array that gets passed in
    def sort_by_structure(nodes)
      arranged = nodes.is_a?(Hash) ? nodes : arrange_nodes(nodes.sort_by{|n| n.structure || '0'})
      arranged.inject([]) do |sorted_nodes, pair|
        node, children = pair
        sorted_nodes << node
        sorted_nodes += sort_by_structure(children) unless children.blank?
        sorted_nodes
      end
    end
 
    
    
  end
end
