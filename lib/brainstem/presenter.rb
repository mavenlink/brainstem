require 'date'
require 'brainstem/time_classes'
require 'brainstem/concerns/presenter_dsl'

module Brainstem
  # @abstract Subclass and override {#present} to implement a presenter.
  class Presenter
    include Concerns::PresenterDSL

    # Class methods

    # Accepts a list of classes this specific presenter knows how to present.  These are not inherited.
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

    def self.ar_preload(models, association_names)
      if Gem.loaded_specs['activerecord'].version >= Gem::Version.create('4.1')
        ActiveRecord::Associations::Preloader.new.preload(models, association_names)
      else
        ActiveRecord::Associations::Preloader.new(models, association_names).run
      end
    end


    # Instance methods

    # @deprecated
    def present(model)
      raise "#present is now deprecated"
    end

    # Calls {#custom_preload} and then presents all models.
    def group_present(models, requested_associations = [], options = {})
      requested_associations_hash = requested_associations.each_with_object({}) do |assoc_name, memo|
        memo[assoc_name.to_s] = configuration[:associations][assoc_name] if configuration[:associations][assoc_name]
      end

      # It's slightly ugly, but more efficient if we pre-load everything we need and pass it through.
      context = {
        conditional_cache: {},
        helper_instance: fresh_helper_instance,
        fields: configuration[:fields],
        conditionals: configuration[:conditionals],
        associations: configuration[:associations],
        reflections: models.first && Brainstem::Presenter.reflections(models.first.class),
        requested_associations_hash: requested_associations_hash
      }

      preload_associations! models, context
      custom_preload(models, requested_associations_hash.keys)

      models.map do |model|
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

      configuration[:filters].each do |filter_name, filter|
        user_value = user_params[filter_name]
        user_value = user_value.is_a?(Array) ? user_value : (user_value.present? ? user_value.to_s : nil)
        user_value = user_value == "true" ? true : (user_value == "false" ? false : user_value)

        filter_options = filter[0]
        filter_arg = apply_default_filters && user_value.nil? ? filter_options[:default] : user_value
        filters_hash[filter_name] = filter_arg unless filter_arg.nil?
      end

      filters_hash
    end

    # Given user params, build a hash of validated filter names to their unsanitized arguments.
    def apply_filters_to_scope(scope, user_params, options)
      helper_instance = fresh_helper_instance

      extract_filters(user_params, options).each do |filter_name, filter_arg|
        filter_lambda = configuration[:filters][filter_name][1]

        if filter_lambda
          scope = helper_instance.instance_exec(scope, filter_arg, &filter_lambda)
        else
          scope = scope.send(filter_name, filter_arg)
        end
      end

      scope
    end

    # Given user params, apply a validated sort order to the given scope.
    def apply_ordering_to_scope(scope, user_params)
      sort_name, direction = calculate_sort_name_and_direction(user_params)
      order = configuration[:sort_orders][sort_name]

      case order
        when Proc
          fresh_helper_instance.instance_exec(scope, direction, &order)
        when nil
          scope
        else
          scope.order(order.to_s + " " + direction)
      end
    end

    # Clean and validate a sort order and direction from user params.
    def calculate_sort_name_and_direction(user_params = {})
      default_column, default_direction = (configuration[:default_sort_order] || "updated_at:desc").split(":")
      sort_name, direction = (user_params['order'] || "").split(":")
      unless sort_name.present? && configuration[:sort_orders][sort_name]
        sort_name = default_column
        direction = default_direction
      end

      [sort_name, direction == 'desc' ? 'desc' : 'asc']
    end

    protected

    # @api protected
    # Run preloading on the given models.
    def preload_associations!(models, context)
      if models.length > 0
        association_names_to_preload = context[:requested_associations_hash].values.map(&:method_name).compact
        association_names_to_preload += configuration[:preloads].to_a
        # todo: better de-duping here when things might be nested hashes?
        association_names_to_preload.uniq!
        if association_names_to_preload.any?
          reflections = context[:reflections]
          association_names_to_preload.reject! { |association| !reflections.has_key?(association.to_s) }
          if association_names_to_preload.any?
            Brainstem::Presenter.ar_preload(models, association_names_to_preload)
          end
        end
      end
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
          when DSL::Field
            if field.conditionals_match?(model, context[:conditionals], context[:helper_instance], context[:conditional_cache])
              result[name] = field.run_on(model, context[:helper_instance])
            end
          when DSL::Configuration
            result[name] ||= {}
            present_fields(model, context, field, result[name])
          else
            raise "Unknown Brianstem Field type encountered: #{field}"
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

        if context[:requested_associations_hash][external_name]
          associated_models = association.run_on(model, context[:helper_instance])

          if options[:load_associations_into]
            Array(associated_models).flatten.each do |associated_model|
              key = association.brainstem_key || DSL::Association.brainstem_key_for(associated_model.class, association.options[:sti_uses_base])
              options[:load_associations_into][key] ||= {}
              options[:load_associations_into][key][associated_model.id.to_s] = associated_model
            end
          end
        end

        if id_attr && model.class.columns_hash.has_key?(id_attr)
          if association.polymorphic? && (reflection = context[:reflections][method_name]) && reflection.options[:polymorphic]
            struct["#{external_name}_ref"] = begin
              if (id = model.send(id_attr)).present?
                {
                  'id' => to_s_except_nil(id),
                  'key' => model.send("#{method_name}_type").try(:tableize)
                }
              end
            end
          else
            struct["#{external_name}_id"] = to_s_except_nil(model.send(id_attr))
          end
        elsif context[:requested_associations_hash][external_name]
          if associated_models.is_a?(Array) || associated_models.is_a?(ActiveRecord::Relation)
            struct["#{external_name.to_s.singularize}_ids"] = associated_models.map {|a| to_s_except_nil(a.is_a?(ActiveRecord::Base) ? a.id : a) }
          else
            struct["#{external_name.to_s.singularize}_id"] = to_s_except_nil(associated_models.is_a?(ActiveRecord::Base) ? associated_models.id : associated_models)
          end
        end
      end
    end

    # @api protected
    # Call to_s on the input unless the input is nil.
    def to_s_except_nil(thing)
      thing.nil? ? nil : thing.to_s
    end
  end
end
