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

          def format_association_relations
            presenter.valid_associations.each do |name, association|
              association_klass = association.target_class.to_s

              if association.type == :has_many
                buffer.puts(%(#{target_class} *-- "n" #{association_klass}))
              else
                buffer.puts(%(#{target_class} o-- "1" #{association_klass}))
              end
            end
          end

          def format_fields
            presenter.valid_fields.each do |_, field|
              buffer.puts("#{field.type} #{field.name.to_s}")
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:presenter][:puml] =
  Brainstem::ApiDocs::Formatters::Puml::PresenterFormatter
