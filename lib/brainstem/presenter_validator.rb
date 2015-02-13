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
    validate :conditionals_exist

    def preloads_exist
      presenter_class.configuration[:preloads].each do |preload|
        if presenter_class.presents.any? { |klass| !klass.new.respond_to?(preload) }
          errors.add(:preload, "not all presented classes respond to '#{preload}'")
        end
      end
    end

    def fields_exist
      presenter_class.configuration[:fields].each do |name, field|
        field_name = field.options[:via] || name
        if presenter_class.presents.any? { |klass| !klass.new.respond_to?(field_name) }
          errors.add(:fields, "'#{name}' is not valid because not all presented classes respond to '#{field_name}'")
        end
      end
    end

    def conditionals_exist
      presenter_class.configuration[:fields].each do |name, field|
        if field.options[:if].present?
          if Array.wrap(field.options[:if]).any? { |conditional| presenter_class.configuration[:conditionals][conditional].nil? }
            errors.add(:fields, "'#{name}' is not valid because one or more of the specified conditions does not exist")
          end
        end
      end
    end
  end
end