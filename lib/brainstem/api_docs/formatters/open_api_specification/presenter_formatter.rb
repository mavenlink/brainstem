require 'active_support/core_ext/string/inflections'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        class PresenterFormatter < AbstractFormatter
          include Helper

          def initialize(presenter, options = {})
            self.presenter = presenter
            self.presented_class = presenter.target_class
            self.output = ActiveSupport::HashWithIndifferentAccess.new
            self.definition = ActiveSupport::HashWithIndifferentAccess.new
            super options
          end

          attr_accessor :presenter,
                        :output,
                        :definition,
                        :presented_class

          def call
            return {} if presenter.nodoc?

            format_title!
            format_description!
            format_type!
            format_fields!

            output.merge!(presented_class => definition.reject { |_, v| v.blank? })
          end


          #####################################################################
          private
          #####################################################################


          def format_title!
            definition.merge! title: presenter_title(presenter)
          end

          def format_description!
            definition.merge! description: presenter.description.to_s.strip
          end

          def format_type!
            definition.merge! type: 'object'
          end

          def format_fields!
            return unless presenter.valid_fields.any?

            definition.merge!('properties' => format_field_branch(presenter.valid_fields))
          end

          def format_field_branch(branch)
            branch.inject({}) do |buffer, (name, field)|
              if nested_field?(field)
                buffer[name.to_s] = {
                    "type" => "object",
                    "properties" => format_field_branch(field.to_h)
                }
              else
                buffer[name.to_s] = format_field_leaf(field)
              end
              buffer
            end
          end

          def nested_field?(field)
            !field.respond_to?(:options)
          end

          def format_field_leaf(field)
            type_info = type_and_format(field.type)

            object = { "description" => field.description.to_s }.merge(type_and_format(field.type) || {})

            if field.options[:if]
              conditions = field.options[:if]
                               .reject { |cond| presenter.conditionals[cond].options[:nodoc] }
                               .map {|cond| presenter.conditionals[cond].description || "" }
                               .delete_if(&:empty?)
                               .join(" and ")

              object["description"] << "\n\nvisible when #{conditions}\n\n" unless conditions.empty?
            end

            if field.optional?
              object["description"] << "only returned when requested through the optional_fields param"
            end
            object["description"].try(:chomp!)
            object.delete("description") if object["description"].blank?

            object
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:presenter][:open_api] = \
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::PresenterFormatter.method(:call)