class << ActiveRecord::Base
  def has_structure(options = {})
    # Check options
    raise Structure::StructureException.new('Options for has_structure must be in a hash.') unless options.is_a? Hash
    options.each do |key, value|
      unless [:structure_column, :orphan_strategy, :cache_depth, :depth_cache_column].include? key
        raise Structure::StructureException.new("Unknown option for has_structure: #{key.inspect} => #{value.inspect}.")
      end
    end

    # Include instance methods
    include Structure::InstanceMethods

    # Include dynamic class methods
    extend Structure::ClassMethods

    # Create structure column accessor and set to option or default
    cattr_accessor :structure_column
    self.structure_column = options[:structure_column] || :structure

    # Create orphan strategy accessor and set to option or default (writer comes from DynamicClassMethods)
    cattr_reader :orphan_strategy
    self.orphan_strategy = options[:orphan_strategy] || :destroy

    # Save self as base class (for STI)
    cattr_accessor :base_class
    self.base_class = self

    # Validate format of ancestry column value
    validates_format_of structure_column, :with => Structure::STRUCTURE_PATTERN, :allow_nil => true

    # Validate that the ancestor ids don't include own id
    validate :structure_exclude_self

    # Named scopes
    scope :roots, -> { where(structure_column => nil) }
    scope :ancestors_of, ->(object) { where(to_node(object).ancestor_conditions) }
    scope :descendants_of, ->(object) {where(to_node(object).descendant_conditions) }
    scope :subtree_of, ->(object) {where(to_node(object).subtree_conditions) }
    scope :ordered_by_structure, -> { reorder("(case when #{table_name}.#{structure_column} is null then 0 else 1 end), #{table_name}.#{structure_column}") }
    scope :ordered_by_structure_and, ->(order) { reorder("(case when #{table_name}.#{structure_column} is null then 0 else 1 end), #{table_name}.#{structure_column}, #{order}") }

    # Update descendants with new structure before save
    before_save :update_descendants_with_new_structure

    # Apply orphan strategy before destroy
    before_destroy :apply_orphan_strategy

    # Create structure column accessor and set to option or default
    if options[:cache_depth]
      # Create accessor for column name and set to option or default
      self.cattr_accessor :depth_cache_column
      self.depth_cache_column = options[:depth_cache_column] || :structure_depth

      # Cache depth in depth cache column before save
      before_validation :cache_depth

      # Validate depth column
      validates_numericality_of depth_cache_column, :greater_than_or_equal_to => 0, :only_integer => true, :allow_nil => false
    end

    
  end

   
end
