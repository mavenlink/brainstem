require 'date'
require 'set' # For possible brainstem keys
require 'brainstem/time_classes'
require 'brainstem/preloader'
require 'brainstem/concerns/presenter_dsl'
require 'active_support/core_ext/hash/except'

module Brainstem
  # @abstract Subclass and override {#present} to implement a presenter.
  class Presenter
    include Concerns::PresenterDSL
    class_attribute :count_evaluator

    # Class methods

    # Accepts a list of classes that this specific presenter knows how to present. These are not inherited.
    # @param [String, [String]] klasses Any number of names of classes this presenter presents.
    def self.presents(*klasses)
      @presents ||= []
      if klasses.length > 0
        if klasses.any? { |klass| klass.is_a?(String) || klass.is_a?(Symbol) }
          raise "Brainstem Presenter#presents now expects a Class instead of a class name"
        end
        @presents.concat(klasses).uniq!
        Brainstem.add_presenter_class(self, namespace, *klasses)
      end
      @presents
    end

    #
    # Returns the set of possible brainstem keys for the classes presented.
    #
    # If the presenter specifies a key, that will be returned as the only
    # member of the set.
    #
    def self.possible_brainstem_keys
      @possible_brainstem_keys ||= begin
        Set.new(presents.map(&presenter_collection.method(:brainstem_key_for!)))
      end
    end

    # Return the second-to-last module in the name of this presenter, which Brainstem considers to be the 'namespace'.
    # E.g., Api::V1::FooPresenter has a namespace of "V1".
    # @return [String] The name of the second-to-last module containing this presenter.
    def self.namespace
      self.to_s.split("::")[-2].try(:downcase)
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
      @helper_classes = @presents = nil
    end

    # In Rails 4.2, ActiveRecord::Base#reflections started being keyed by strings instead of symbols.
    def self.reflections(klass)
      klass.reflections.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value }
    end

    # Instance methods

    # @deprecated
    def present(model)
      raise "#present is now deprecated"
    end

    def get_query_strategy
      if configuration.has_key? :query_strategy
        strat = configuration[:query_strategy]
        strat.respond_to?(:call) ? fresh_helper_instance.instance_exec(&strat) : strat
      end
    end

    # Calls {#custom_preload} and then presents all models.
    # @params [ActiveRecord::Relation, Array] models
    # @params [Array] requested_associations An array of permitted lower-case string association names, e.g. 'post'
    # @params [Hash] options The options passed to `load_associations!`
    def group_present(models, requested_associations = [], options = {})
      association_objects_by_name = requested_associations.each_with_object({}) do |assoc_name, memo|
        memo[assoc_name.to_s] = configuration[:associations][assoc_name] if configuration[:associations][assoc_name]
      end

      # It's slightly ugly, but more efficient if we pre-load everything we
      # need and pass it through.
      context = {
        conditional_cache:            { request: {} },
        fields:                       configuration[:fields],
        conditionals:                 configuration[:conditionals],
        associations:                 configuration[:associations],
        reflections:                  reflections_for_model(models.first),
        association_objects_by_name:  association_objects_by_name,
        optional_fields:              options[:optional_fields] || [],
        models:                       models,
        lookup:                       empty_lookup_cache(configuration[:fields].keys, association_objects_by_name.keys)
      }

      sanitized_association_names = association_objects_by_name.values.map(&:method_name)
      preload_associations! models, sanitized_association_names, context[:reflections]

      # Legacy: Overridable for custom preload behavior.
      custom_preload(models, association_objects_by_name.keys)

      models.map do |model|
        context[:conditional_cache][:model] = {}
        context[:helper_instance] = fresh_helper_instance
        result = present_fields(model, context, context[:fields])
        load_associations!(model, result, context, options)
        add_id!(model, result)
        datetimes_to_json(result)
      end
    end

    def present_model(model, requested_associations = [], options = {})
      group_present([model], requested_associations, options).first
    end

    # @api private
    #
    # Returns the reflections for a model's class if the model is not nil.
    def reflections_for_model(model)
      model && Brainstem::Presenter.reflections(model.class)
    end
    private :reflections_for_model

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

    # Subclasses can define this if they wish. This method will be called by {#group_present}.
    def custom_preload(models, requested_associations = [])
    end

    # Given user params, build a hash of validated filter names to their unsanitized arguments.
    def extract_filters(user_params, options = {})
      filters_hash = {}

      apply_default_filters = options.fetch(:apply_default_filters) { true }

      configuration[:filters].each do |filter_name, filter_options|
        user_value = format_filter_value(user_params[filter_name])

        filter_arg = apply_default_filters && user_value.nil? ? filter_options[:default] : user_value
        filters_hash[filter_name] = filter_arg unless filter_arg.nil?
      end

      filters_hash
    end

    # @api private
    # @param [Array, Hash, String, Boolean, nil] value
    #
    # @return [Array, Hash, String, Boolean, nil]
    def format_filter_value(value)
      return value if value.is_a?(Array) || value.is_a?(Hash)
      return nil if value.blank?

      value = value.to_s
      case value
        when 'true', 'TRUE' then true
        when 'false', 'FALSE' then false
        else
          value
      end
    end
    private :format_filter_value

    # Given user params, build a hash of validated filter names to their unsanitized arguments.
    def apply_filters_to_scope(scope, user_params, options)
      helper_instance = fresh_helper_instance

      requested_filters = extract_filters(user_params, options)
      requested_filters.each do |filter_name, filter_arg|
        filter_lambda = configuration[:filters][filter_name][:value]

        args_for_filter_lambda = [filter_arg]
        args_for_filter_lambda << requested_filters if configuration[:filters][filter_name][:include_params]

        if filter_lambda
          scope = helper_instance.instance_exec(scope, *args_for_filter_lambda, &filter_lambda)
        else
          scope = scope.send(filter_name, *args_for_filter_lambda)
        end
      end

      scope
    end

    # Given user params, apply a validated sort order to the given scope.
    def apply_ordering_to_scope(scope, user_params)
      sort_name, direction = calculate_sort_name_and_direction(user_params)
      order = configuration[:sort_orders].fetch(sort_name, {})[:value]

      ordered_scope = case order
        when Proc
          fresh_helper_instance.instance_exec(scope, direction, &order)
        when nil
          scope
        else
          scope.reorder(Arel.sql(order.to_s + " " + direction))
      end

      fallback_deterministic_sort = assemble_primary_key_sort(scope)
      # Chain on a tiebreaker sort to ensure deterministic ordering of multiple pages of data

      if fallback_deterministic_sort
        ordered_scope.order(fallback_deterministic_sort)
      else
        ordered_scope
      end
    end

    def assemble_primary_key_sort(scope)
      table_name = scope.table.name
      primary_key = scope.model.primary_key

      if table_name && primary_key
        Arel.sql("#{scope.connection.quote_table_name(table_name)}.#{scope.connection.quote_column_name(primary_key)} ASC")
      else
        nil
      end
    end
    private :assemble_primary_key_sort

    # Execute the stored search block
    def run_search(query, search_options)
      fresh_helper_instance.instance_exec(query, search_options, &configuration[:search])
    end

    # Clean and validate a sort order and direction from user params.
    def calculate_sort_name_and_direction(user_params = {})
      default_column, default_direction = (configuration[:default_sort_order] || "updated_at:desc").split(":")
      sort_name, direction = user_params['order'].to_s.split(":")
      unless sort_name.present? && configuration[:sort_orders][sort_name]
        sort_name = default_column
        direction = default_direction
      end

      [sort_name, direction == 'desc' ? 'desc' : 'asc']
    end

    protected

    # @api protected
    # Run preloading on the given models, asking Rails to include both any named associations and any preloads declared in the Brainstem DSL..
    def preload_associations!(models, sanitized_association_names, memoized_reflections)
      return unless models.any?

      preloads  = sanitized_association_names + configuration[:preloads].to_a
      Brainstem::Preloader.preload(models, preloads, memoized_reflections)
    end

    # @api protected
    # Instantiate and return a new instance of the merged helper class for this presenter.
    def fresh_helper_instance
      self.class.merged_helper_class.new
    end

    # @api protected
    # Adds :id as a string from the given model.
    def add_id!(model, struct)
      if model.class.respond_to?(:primary_key)
        struct['id'] = model[model.class.primary_key].to_s
      end
    end

    # @api protected
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

    # @api protected
    # Uses the fields DSL to output a presented model.
    # @return [Hash]  A hash representation of the model.
    def present_fields(model, context, fields, result = {})
      fields.each do |name, field|
        case field
          when DSL::HashBlockField
            next if field.executable? && !field.presentable?(model, context)

            # This preserves backwards compatibility
            # In the case of a hash field, the individual attributes will call presentable
            # If none of the individual attributes are presentable we will receive an empty hash
            result[name] = field.run_on(model, context, context[:helper_instance])
          when DSL::ArrayBlockField, DSL::Field
            if field.presentable?(model, context)
              result[name] = field.run_on(model, context, context[:helper_instance])
            end
          else
            raise "Unknown Brainstem Field type encountered: #{field}"
        end
      end
      result
    end

    # @api protected
    # Makes sure that associations are loaded and converted into ids.
    def load_associations!(model, struct, context, options)
      context[:associations].each do |external_name, association|
        method_name = association.method_name && association.method_name.to_s
        id_attr = method_name && "#{method_name}_id"

        # If this association has been explictly requested, execute the association here.  Additionally, store
        # the loaded models in the :load_associations_into hash for later use.
        if context[:association_objects_by_name][external_name]
          associated_model_or_models = association.run_on(model, context, context[:helper_instance])

          if options[:load_associations_into]
            Array(associated_model_or_models).flatten.each do |associated_model|
              key = presenter_collection.brainstem_key_for!(associated_model.class)
              options[:load_associations_into][key] ||= {}
              options[:load_associations_into][key][associated_model.id.to_s] = associated_model
            end
          end
        end

        if id_attr && model.class.columns_hash.has_key?(id_attr) && !association.polymorphic?
          # We return *_id keys when they exist in the database, because it's free to do so.
          struct["#{external_name}_id"] = to_s_except_nil(model.send(id_attr))
        elsif association.always_return_ref_with_sti_base?
          # Deprecated support for legacy always-return-ref mode without loading the association.
          struct["#{external_name}_ref"] = legacy_polymorphic_base_ref(model, id_attr, method_name)
        elsif context[:association_objects_by_name][external_name]
          # This association has been explicitly requested.  Add the *_id, *_ids, *_ref, or *_refs keys to the presented data.
          add_ids_or_refs_to_struct!(struct, association, external_name, associated_model_or_models)
        end
      end
    end

    # @api protected
    # Inject 'foo_ids' keys into the presented data if the foos association has been requested.
    def add_ids_or_refs_to_struct!(struct, association, external_name, associated_model_or_models)
      singular_external_name = external_name.to_s.singularize
      if association.polymorphic?
        if associated_model_or_models.is_a?(Array) || associated_model_or_models.is_a?(ActiveRecord::Relation)
          struct["#{singular_external_name}_refs"] = associated_model_or_models.map { |associated_model| make_model_ref(associated_model) }
        else
          struct["#{singular_external_name}_ref"] = make_model_ref(associated_model_or_models)
        end
      else
        if associated_model_or_models.is_a?(Array) || associated_model_or_models.is_a?(ActiveRecord::Relation)
          struct["#{singular_external_name}_ids"] = associated_model_or_models.map { |associated_model| to_s_except_nil(associated_model.try(:id)) }
        else
          struct["#{singular_external_name}_id"] = to_s_except_nil(associated_model_or_models.try(:id))
        end
      end
    end

    # @api protected
    # Deprecated support for legacy always-return-ref mode without loading the association.
    # This tries to find the key based on the *_type value in the DB (which will be the STI base class, and may error if no presenter exists)
    def legacy_polymorphic_base_ref(model, id_attr, method_name)
      if (id = model.send(id_attr)).present?
        {
          'id' => to_s_except_nil(id),
          'key' => presenter_collection.brainstem_key_for!(model.send("#{method_name}_type").try(:constantize))
        }
      end
    end

    # @api protected
    # Call to_s on the input unless the input is nil.
    def to_s_except_nil(thing)
      thing.nil? ? nil : thing.to_s
    end

    # @api protected
    # Return a polymorphic id/key object for a model, or nil if no model was given.
    def make_model_ref(model)
      if model
        {
          'id' => to_s_except_nil(model.id),
          'key' => presenter_collection.brainstem_key_for!(model.class)
        }
      else
        nil
      end
    end

    def self.presenter_collection
      Brainstem.presenter_collection(namespace)
    end

    # @api protected
    # Find the global presenter collection for our namespace.
    def presenter_collection
      self.class.presenter_collection
    end

    # @api protected
    # Create an empty lookup cache with the fields and associations as keys and nil for the values
    # @return [Hash]
    def empty_lookup_cache(field_keys, association_keys)
      {
        fields: Hash[field_keys.map { |key| [key, nil] }],
        associations: Hash[association_keys.map { |key| [key, nil] }]
      }
    end
  end
end
