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

            buffer.puts("class " + presenter.target_class + " {")
            format_fields
            buffer.puts("}")
            format_associations
            buffer.string
          end

          private

          def format_associations
            buffer.puts(%(User o-- "1" Cheese)) if presenter.target_class == 'User'
          end

          def buffer
            @buffer ||= StringIO.new
          end

          attr_reader :presenter

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
