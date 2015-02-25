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


    # Instance methods

    # @deprecated
    def present(model)
      raise "#present is now deprecated"
    end

    # Calls {#custom_preload} and then presents all models.
    def group_present(models, requested_associations = [], options = {})
      custom_preload models, requested_associations.map(&:to_s)

      # It's slightly ugly, but more efficient if we pre-load everything we need and pass it through.
      context = {
        conditional_cache: {},
        helper_instance: fresh_helper_instance,
        fields: configuration[:fields],
        conditionals: configuration[:conditionals],
        associations: configuration[:associations],
        reflections: models.first && Brainstem::PresenterCollection.reflections(models.first.class),
        requested_associations_hash: requested_associations.inject({}) { |memo, association| memo[association] = true; memo }
      }

      models.map do |model|
        result = present_fields(model, context, context[:fields])
        load_associations!(model, result, context, options)
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
    def run_filters(scope, user_params, options)
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

    protected

    # @api private
    # Instantiate and return a new instance of the merged helper class for this presenter.
    def fresh_helper_instance
      self.class.merged_helper_class.new
    end

    # @api private
    # Adds :id as a string from the given model.
    def add_id!(model, struct)
      if model.class.respond_to?(:primary_key)
        struct['id'] = model[model.class.primary_key].to_s
      end
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

    # @api private
    # Makes sure that associations are loaded and converted into ids.
    def load_associations!(model, struct, context, options)
      context[:associations].each do |name, association|
        external_name = association.name
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

    def to_s_except_nil(thing)
      thing.nil? ? nil : thing.to_s
    end
  end
end
