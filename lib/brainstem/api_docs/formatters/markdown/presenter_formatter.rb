require 'active_support/core_ext/string/inflections'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/markdown/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        class PresenterFormatter < AbstractFormatter
          include Helper


          def initialize(presenter, options = {})
            self.presenter = presenter
            self.output    = ""
            super options
          end


          attr_accessor :presenter,
                        :output


          def call
            return output if presenter.nodoc?

            format_title!
            format_brainstem_keys!
            format_description!
            format_fields!
            format_filters!
            format_sort_orders!
            format_associations!

            output
          end


          #####################################################################
          private
          #####################################################################

          def format_title!
            output << md_h4(presenter.title)
          end


          def format_brainstem_keys!
            text = "Top-level key: "
            text << presenter.brainstem_keys
              .map(&method(:md_inline_code))
              .join(" / ")

            output << md_p(text)
          end


          def format_description!
            output << md_p(presenter.description) unless presenter.description.empty?
          end


          def format_field_leaf(field, indent_level)
            text = md_inline_code(field.name.to_s)
            text << " (#{md_inline_code(field.type.to_s.capitalize)})"

            text << "\n"
            text << md_li(field.description, indent_level + 1) if field.description

            if field.options[:if]
              conditions = field.options[:if]
                .reject { |cond| presenter.conditionals[cond].options[:nodoc] }
                .map {|cond| presenter.conditionals[cond].description || "" }
                .delete_if(&:empty?)
                .join(" and ")

              text << md_li("visible when #{conditions}", indent_level + 1) unless conditions.empty?
            end

            text << md_li("only returned when requested through the #{md_inline_code("optional_fields")} param") if field.optional?
            text.chomp!
          end


          def format_field_branch(branch, indent_level = 0)
            branch.inject("") do |buffer, (name, field)|
              if nested_field?(field)
                sub_fields = md_inline_code(name.to_s) + "\n"
                sub_fields << format_field_branch(field.to_h, indent_level + 1)
                buffer     += md_li(sub_fields, indent_level)
              else
                buffer += md_li(format_field_leaf(field, indent_level), indent_level)
              end
            end
          end


          def nested_field?(field)
            !field.respond_to?(:options)
          end


          def format_fields!
            output << md_h5("Fields")

            if presenter.valid_fields.any?

              output << md_ul do
                format_field_branch(presenter.valid_fields)
              end
            else
              output << md_p("No fields were listed.")
            end
          end


          def format_filters!
            if presenter.valid_filters.any?
              output << md_h5("Filters")
              output << md_ul do
                presenter.valid_filters.inject("") do |buffer, (name, opts)|
                  text = md_inline_code(name)

                  if opts[:info]
                    text << "\n"
                    text << md_li(opts[:info], 1)
                    text.chomp!
                  end

                  buffer += md_li(text)
                end
              end
            end
          end


          def format_sort_orders!
            if presenter.valid_sort_orders.any?
              output << md_h5("Sort Orders")
              output << md_ul do
                sorted_orders = presenter.valid_sort_orders.sort_by { |name, _| name.to_s }

                # Shift the default sort_order to the top
                sorted_orders.unshift sorted_orders.delete_at(sorted_orders.index { |name, _| name.to_s == presenter.default_sort_field })

                sorted_orders.inject("") do |buffer, (name, opts)|
                  text = "#{md_inline_code(name.to_s)}"

                  if presenter.default_sort_field == name.to_s
                    text += " - #{md_strong("default")} (#{presenter.default_sort_direction})"
                  end

                  if opts[:info]
                    text += "\n" + md_li(opts[:info], 1)
                    text.chomp!
                  end

                  buffer += md_li(text)
                end
              end
            end
          end


          def format_associations!
            if presenter.valid_associations.any?
              output << md_h5("Associations")
              output << md_ul do
                presenter.valid_associations.inject("") do |buffer, (_, association)|
                  link = presenter.link_for_association(association)
                  text = md_inline_code(association.name)
                  text = md_a(text, link) if link

                  text << "\n"
                  text << md_li(association.description, 1) \
                    if association.description && !association.description.empty?
                  text << md_li("Restricted to queries with #{md_inline_code(":only")} parameter", 1) \
                    if association.options && association.options[:restrict_to_only]
                  text.chomp!

                  buffer << md_li(text)
                end
              end
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:presenter][:markdown] = \
  Brainstem::ApiDocs::Formatters::Markdown::PresenterFormatter.method(:call)
