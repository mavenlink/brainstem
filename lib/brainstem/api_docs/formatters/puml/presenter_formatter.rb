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

            buffer.puts("class " + target_class + " {")
            format_fields
            buffer.puts("}")

            format_association_relations

            buffer.string
          end

          private

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
            presenter.valid_associations.each do |name, association|
              association_klass = association.target_class.to_s
              association_key = format_association_key(association)

              buffer.puts(%(#{target_class} #{association_connector(association)} #{association_klass} : #{association_key}))
            end
          end

          def association_connector(association)
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
