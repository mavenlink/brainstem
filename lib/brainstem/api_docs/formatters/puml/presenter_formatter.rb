require 'brainstem/api_docs/formatters/abstract_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module Puml
        class PresenterFormatter < AbstractFormatter
          attr_accessor :add_association_class_definitions

          #
          # Declares the options that are permissable to set on this instance.
          #
          def valid_options
            super | [
              :add_association_class_definitions
            ]
          end

          def initialize(presenter, options = {})
            @presenter = presenter
            @add_association_class_definitions = false

            super options
          end

          def call
            return "" if presenter.nodoc?

            format_class_definition(presenter)
            format_association_relations

            buffer.string
          end

          private

          attr_reader :presenter

          def open_class_definition(given_presenter)
            buffer.puts("class " + given_presenter.target_class + " {")
          end

          def close_class_definition
            buffer.puts("}")
          end

          def buffer
            @buffer ||= StringIO.new
          end

          def target_class
            presenter.target_class
          end

          def format_class_definition(given_presenter)
            open_class_definition(given_presenter)
            format_fields(given_presenter)
            close_class_definition
          end

          def format_fields(given_presenter)
            given_presenter.valid_fields.sort.each do |_, field|
              buffer.puts("#{field.type} #{field.name}")
            end
          end

          def format_association_relations
            presenter.valid_associations.each do |_name, association|
              associated_classes_with_labels(association).each do |associated_class, label|
                if add_association_class_definitions
                  associated_presenter = presenter.find_by_class(associated_class)
                  format_class_definition(associated_presenter)
                end

                buffer.puts(connect(association, associated_class, label))
              end
            end
          end

          def associated_classes_with_labels(association)
            if association.polymorphic?
              Array.wrap(association.polymorphic_classes).map do |polymorphic_class|
                [
                  polymorphic_class,
                  association.name
                ]
              end
            else
              [
                [
                  association.target_class,
                  format_association_key(association)
                ]
              ]
            end
          end

          def connect(association, klass, label)
            %(#{target_class} #{connector(association)} #{klass} : #{label})
          end

          def connector(association)
            association.type == :has_many ? '*-- "n"' : 'o-- "1"'
          end

          def format_association_key(association)
            return association.response_key if association.response_key.present?

            key = association.name.singularize
            association.type == :has_many ? "#{key}_ids" : "#{key}_id"
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:presenter][:puml] =
  Brainstem::ApiDocs::Formatters::Puml::PresenterFormatter
