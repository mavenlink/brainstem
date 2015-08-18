module Brainstem
  class PresenterValidator
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks

    attr_accessor :presenter_class

    def initialize(presenter_class)
      @presenter_class = presenter_class
    end

    validate :preloads_exist
    validate :fields_exist
    validate :associations_exist
    validate :conditionals_exist

    def preloads_exist
      presenter_class.configuration[:preloads].each do |preload|
        Array(preload.is_a?(Hash) ? preload.keys : preload).each do |association_name|
          if presenter_class.presents.any? { |klass| !klass.new.respond_to?(association_name) }
            errors.add(:preload, "not all presented classes respond to '#{association_name}'")
          end
        end
      end
    end

    def fields_exist(fields = presenter_class.configuration[:fields])
      fields.each do |name, field_or_fields|
        case field_or_fields
          when DSL::Field
            method_name = field_or_fields.method_name
            if method_name && presenter_class.presents.any? { |klass| !klass.new.respond_to?(method_name) }
              errors.add(:fields, "'#{name}' is not valid because not all presented classes respond to '#{method_name}'")
            end
          when DSL::Configuration
            fields_exist(field_or_fields)
        end
      end
    end

    def associations_exist(associations = presenter_class.configuration[:associations])
      associations.each do |name, association|
        method_name = association.method_name

        if !association.polymorphic? && !Brainstem.presenter_collection.for(association.target_class)
          errors.add(:associations, "'#{name}' is not valid because no presenter could be found for the #{association.target_class} class")
        end

        if method_name && presenter_class.presents.any? { |klass| !klass.new.respond_to?(method_name) }
          errors.add(:associations, "'#{name}' is not valid because not all presented classes respond to '#{method_name}'")
        end
      end
    end

    def conditionals_exist(fields = presenter_class.configuration[:fields])
      fields.each do |name, field_or_fields|
        case field_or_fields
          when DSL::Field
            if field_or_fields.options[:if].present?
              if Array.wrap(field_or_fields.options[:if]).any? { |conditional| presenter_class.configuration[:conditionals][conditional].nil? }
                errors.add(:fields, "'#{name}' is not valid because one or more of the specified conditionals does not exist")
              end
            end
          when DSL::Configuration
            conditionals_exist(field_or_fields)
        end
      end
    end
  end
end