require 'brainstem/api_docs/formatters/abstract_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module Puml
        class PresenterFormatter < AbstractFormatter
          def initialize(presenter, options = {})
            @presenter = presenter
            super options
          end

          def call
            return "" if presenter.nodoc?

            open_class_definition
            format_fields
            close_class_definition
            format_association_relations

            buffer.string
          end

          private

          def open_class_definition
            buffer.puts("class " + target_class + " {")
          end

          def close_class_definition
            buffer.puts("}")
          end

          attr_reader :presenter

          def buffer
            @buffer ||= StringIO.new
          end

          def target_class
            presenter.target_class
          end

          def format_fields
            presenter.valid_fields.each do |_, field|
              buffer.puts("#{field.type} #{field.name.to_s}")
            end
          end

          def format_association_relations
            presenter.valid_associations.each do |_name, association|
              associated_connections(association).each { |connection| buffer.puts(connection) }
            end
          end

          def associated_connections(association)
            if association.polymorphic?
              association.polymorphic_classes.map do |polymorphic_class|
                connect(association, polymorphic_class, association.name)
              end
            else
              association_klass = association.target_class
              association_key = format_association_key(association)

              [connect(association, association_klass, association_key)]
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
