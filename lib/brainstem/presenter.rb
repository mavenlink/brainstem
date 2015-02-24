require 'date'
require 'brainstem/time_classes'
require 'brainstem/concerns/presenter_dsl'

module Brainstem
  # @abstract Subclass and override {#present} to implement a presenter.
  class Presenter
    include Concerns::PresenterDSL

    # Class methods

    # Accepts a list of classes this presenter knows how to present.
    # @param [String, [String]] klasses Any number of names of classes this presenter presents.
    def self.presents(*klasses)
      @presents ||= []
      if klasses.length > 0
        if klasses.any? { |klass| klass.is_a?(String) || klass.is_a?(Symbol) }
          raise "Brainstem Presenter#presents now expects a Class instead of a class name"
        end
        @presents += klasses
        Brainstem.add_presenter_class(self, *klasses)
      end
      @presents
    end

    # @overload default_sort_order(sort_string)
    #   Sets a default sort order.
    #   @param [String] sort_string The sort order to apply by default while presenting. The string must contain the name of a sort order that has explicitly been declared using {sort_order}. The string may end in +:asc+ or +:desc+ to indicate the default order's direction.
    #   @return [String] The new default sort order.
    # @overload default_sort_order
    #   @return [String] The default sort order, or nil if one is not set.
    def self.default_sort_order(sort_string = nil)
      if sort_string
        @default_sort_order = sort_string
      else
        @default_sort_order
      end
    end

    # @overload sort_order(name, order)
    #   @param [Symbol] name The name of the sort order.
    #   @param [String] order The SQL string to use to sort the presented data.
    # @overload sort_order(name, &block)
    #   @yieldparam scope [ActiveRecord::Relation] The scope representing the data being presented.
    #   @yieldreturn [ActiveRecord::Relation] A new scope that adds ordering requirements to the scope that was yielded.
    #   Create a named sort order, either containing a string to use as ORDER in a query, or with a block that adds an order Arel predicate to a scope.
    # @raise [ArgumentError] if neither an order string or block is given.
    def self.sort_order(name, order = nil, &block)
      raise ArgumentError, "A sort order must be given" unless block_given? || order
      @sort_orders ||= HashWithIndifferentAccess.new
      @sort_orders[name] = (block_given? ? block : order)
    end

    # @return [Hash] All defined sort orders, keyed by their name.
    def self.sort_orders
      @sort_orders
    end

    # @overload filter(name, options = {})
    #   @param [Symbol] name The name of the scope that may be applied as a filter.
    #   @option options [Object] :default If set, causes this filter to be applied to every request. If the filter accepts parameters, the value given here will be passed to the filter when it is applied.
    # @overload filter(name, options = {}, &block)
    #   @param [Symbol] name The filter can be requested using this name.
    #   @yieldparam scope [ActiveRecord::Relation] The scope that the filter should use as a base.
    #   @yieldparam arg [Object] The argument passed when the filter was requested.
    #   @yieldreturn [ActiveRecord::Relation] A new scope that filters the scope that was yielded.
    def self.filter(name, options = {}, &block)
      @filters ||= HashWithIndifferentAccess.new
      @filters[name] = [options, (block_given? ? block : nil)]
    end

    # @return [Hash]  All defined filters, keyed by their name.
    def self.filters
      @filters
    end

    def self.search(&block)
      @search_block = block
    end

    def self.search_block
      @search_block
    end

    def self.merged_helper_class
      @helper_classes ||= {}

      @helper_classes[configuration[:helpers].to_a.map(&:object_id)] ||= begin
        Class.new.tap do |klass|
          (configuration[:helpers] || []).each do |helper|
            klass.send :include, helper
          end
        end
      end
    end

    def self.reset!
      clear_configuration!
      @helper_classes = @presents = @default_sort_order = @sort_orders = @filters = @search_block = nil
    end


    # Instance methods

    # @deprecated
    def present(model)
      raise "#present is now deprecated"
    end

    # @api private
    # Uses the fields DSL to output a presented model.
    # @return [Hash]  A hash representation of the model.
    def present_fields(model, conditional_cache = {}, helper_instance = fresh_helper_instance, result = {},
                       fields = configuration[:fields], conditionals = configuration[:conditionals])
      fields.each do |name, field|
        case field
          when DSL::Field
            if field.conditionals_match?(model, conditionals, helper_instance, conditional_cache)
              result[name] = field.run_on(model, helper_instance)
            end
          when DSL::Configuration
            result[name] ||= {}
            present_fields(model, conditional_cache, helper_instance, result[name], field, conditionals)
          else
            raise "Unknown Brianstem Field type encountered: #{field}"
        end
      end
      result
    end

    # @api private
    # Instantiate and return a new instance of the merged helper class for this presenter.
    def fresh_helper_instance
      self.class.merged_helper_class.new
    end

    # @api private
    # Adds :id as a string from the given model.
    def add_id!(model, struct)
      if model.class.respond_to?(:primary_key)
        struct[:id] = model[model.class.primary_key].to_s
      end
    end

    # @api private
    # Calls {#custom_preload}, and then {#present} and {#post_process}, for each model.
    def group_present(models, requested_associations = [], options = {})
      custom_preload models, requested_associations.map(&:to_s)

      requested_associations_hash = requested_associations.inject({}) { |memo, association| memo[association] = true; memo }
      reflections = models.first && Brainstem::PresenterCollection.reflections(models.first.class)

      conditional_cache = {}
      helper_instance = fresh_helper_instance
      fields = configuration[:fields]
      conditionals = configuration[:conditionals]
      associations = configuration[:associations]

      models.map do |model|
        result = present_fields(model, conditional_cache, helper_instance, {}, fields, conditionals)
        load_associations!(model, result, associations, requested_associations_hash, reflections, helper_instance)
        add_id!(model, result)
        datetimes_to_json(result)
      end
    end

    # @api private
    # Determines which associations are valid for inclusion in the current context.
    # Mostly just removes only-restricted associations when needed.
    # @return [Hash] The associations that can be included.
    def allowed_associations(is_only_query)
      ActiveSupport::HashWithIndifferentAccess.new.tap do |associations|
        configuration[:associations].each do |name, association|
          associations[name] = association unless association.options[:restrict_to_only] && !is_only_query
        end
      end
    end

    # Subclasses can define this if they wish. This method will be called before {#present}.
    def custom_preload(models, requested_associations = [])
    end

    # @api private
    # Recurses through any nested Hash/Array data structure, converting dates and times to JSON standard values.
    def datetimes_to_json(struct)
      case struct
      when Array
        struct.map { |value| datetimes_to_json(value) }
      when Hash
        processed = {}
        struct.each { |k,v| processed[k] = datetimes_to_json(v) }
        processed
      when Date
        struct.strftime('%F')
      when *TIME_CLASSES # Time, ActiveSupport::TimeWithZone
        struct.iso8601
      else
        struct
      end
    end

    # @api private
    # Makes sure that associations are loaded and converted into ids.
    def load_associations!(model, struct, associations, requested_associations_hash, reflections, helper_instance)
      associations.each do |name, association|
        external_name = association.name
        method_name = association.method_name && association.method_name.to_s
        id_attr = method_name && "#{method_name}_id"

        if id_attr && model.class.columns_hash.has_key?(id_attr)
          if association.polymorphic? && (reflection = reflections[method_name]) && reflection.options[:polymorphic]
            struct["#{external_name}_ref".to_sym] = begin
              if (id = model.send(id_attr)).present?
                {
                  :id => to_s_except_nil(id),
                  :key => model.send("#{method_name}_type").try(:tableize)
                }
              end
            end
          else
            struct["#{external_name}_id".to_sym] = to_s_except_nil(model.send(id_attr))
          end
        elsif requested_associations_hash[external_name]
          result = association.run_on(model, helper_instance)
          if result.is_a?(Array) || result.is_a?(ActiveRecord::Relation)
            struct["#{external_name.to_s.singularize}_ids".to_sym] = result.map {|a| to_s_except_nil(a.is_a?(ActiveRecord::Base) ? a.id : a) }
          else
            struct["#{external_name.to_s.singularize}_id".to_sym] = to_s_except_nil(result.is_a?(ActiveRecord::Base) ? result.id : result)
          end
        end
      end
    end

    # @!attribute [r] default_sort_order
    # The default sort order set on this presenter's class.
    def default_sort_order
      self.class.default_sort_order
    end

    # @!attribute [r] sort_orders
    # The sort orders that were declared in the definition of this presenter.
    def sort_orders
      self.class.sort_orders
    end

    # @!attribute [r] filters
    # The filters that were declared in the definition of this presenter.
    def filters
      self.class.filters
    end

    def search_block
      self.class.search_block
    end

    def to_s_except_nil(thing)
      thing.nil? ? nil : thing.to_s
    end
  end
end
