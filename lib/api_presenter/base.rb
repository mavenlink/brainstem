require 'date'
require 'api_presenter/association_field'
require 'api_presenter/optional_field'
require 'api_presenter/time_classes'

module ApiPresenter
  class Base

    # Class methods

    def self.presents(*klasses)
      ApiPresenter.add_presenter_class(self, *klasses)
    end

    def self.default_sort_order(sort_string = nil)
      if sort_string
        @default_sort_order = sort_string
      else
        @default_sort_order
      end
    end

    def self.sort_order(name, order = nil, &block)
      @sort_orders ||= {}
      @sort_orders[name] = (block_given? ? block : order)
    end

    def self.sort_orders
      @sort_orders
    end

    def self.filter(name, options = {}, &block)
      @filters ||= {}
      @filters[name] = [options, (block_given? ? block : nil)]
    end

    def self.filters
      @filters
    end

    def self.helper(mod)
      include mod
      extend mod
    end


    # Instance methods

    def present(model)
      raise "Please override #present(model) in your subclass of ApiPresenter::Base"
    end

    def present_and_post_process(model, fields = [], associations = [])
      post_process(present(model), model, fields, associations)
    end

    def post_process(struct, model, fields = [], associations = [])
      load_associations!(model, struct, associations)
      load_optional_fields!(model, struct, fields)
      struct = dates_to_strings(struct)
      datetimes_to_epoch(struct)
    end

    def group_present(models, fields = [], associations = [])
      custom_preload models, fields, associations

      models.map do |model|
        present_and_post_process model, fields, associations
      end
    end

    def custom_preload(models, fields = [], associations = [])
      # Subclasses can overload this if they wish.
    end

    def datetimes_to_epoch(struct)
      case struct
      when Array
        struct.map { |value| datetimes_to_epoch value }
      when Hash
        struct.inject({}) { |memo, (k, v)| memo[k] = datetimes_to_epoch v; memo }
      when *TIME_CLASSES # Time, ActiveSupport::TimeWithZone
        struct.to_i
      else
        struct
      end
    end

    def dates_to_strings(struct)
      case struct
        when Array
          struct.map { |value| dates_to_strings value }
        when Hash
          struct.inject({}) { |memo, (k, v)| memo[k] = dates_to_strings v; memo }
        when Date
          struct.strftime('%F')
        else
          struct
      end
    end

    def load_optional_fields!(model, struct, fields)
      struct.to_a.each do |key, value|
        if value.is_a?(FieldProxy) && value.optional
          if fields.include?(key)
            struct[key] = value.call(model)
          else
            struct.delete key
          end
        end
      end
    end

    def load_associations!(model, struct, associations)
      struct.to_a.each do |key, value|
        if value.is_a?(AssociationField)
          struct.delete key
          id_attr = value.method_name ? "#{value.method_name}_id" : nil

          if id_attr && model.class.columns_hash.has_key?(id_attr)
            struct["#{key}_id".to_sym] = model.send(id_attr)
            reflection = value.method_name && model.reflections[value.method_name.to_sym]
            if reflection && reflection.options[:polymorphic]
              struct["#{key.to_s.singularize}_type".to_sym] = model.send("#{value.method_name}_type")
            end
          elsif associations.include?(key)
            result = value.call(model)
            if result.is_a?(Array)
              struct["#{key.to_s.singularize}_ids".to_sym] = result.map {|a| a.is_a?(ActiveRecord::Base) ? a.id : a }
            else
              if result.is_a?(ActiveRecord::Base)
                struct["#{key.to_s.singularize}_id".to_sym] = result.id
              else
                struct["#{key.to_s.singularize}_id".to_sym] = result
              end
            end
          end
        end
      end
    end

    def default_sort_order
      self.class.default_sort_order
    end

    def sort_orders
      self.class.sort_orders
    end

    def filters
      self.class.filters
    end

    def association(method_name = nil, options = {}, &block)
      AssociationField.new method_name, options, &block
    end

    def optional_field(field_name = nil, &block)
      FieldProxy.new field_name, {:optional => true}, &block
    end
  end
end
