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
            text << md_inline_type(field.type, field.options[:item_type])

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
                sub_fields = format_field_leaf(field, indent_level) + "\n"
                sub_fields << format_field_branch(field.to_h, indent_level + 1)
                buffer += md_li(sub_fields, indent_level)
              else
                buffer += md_li(format_field_leaf(field, indent_level), indent_level)
              end
            end
          end

          def nested_field?(field)
            field.respond_to?(:configuration)
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
                  text << md_inline_type(opts[:type])

                  if opts[:info] || opts[:items]
                    description = opts[:info].to_s

                    if opts[:items].present?
                      description += "." unless description =~ /\.\s*\z/
                      description += " Available values: #{opts[:items].join(', ')}."
                    end

                    text << "\n"
                    text << md_li(description, 1)
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
            return if presenter.valid_associations.empty?

            output << md_h5("Associations")

            output << "Association Name | Associated Class | Description\n"
            output << " --------------  |  --------------  |  ----------\n"

            output << presenter.valid_associations.inject("") do |buffer, (_, association)|
              link = presenter.link_for_association(association)
              if link
                link = md_a(association.target_class, link)
              else
                link = association.target_class.to_s
              end

              desc = association.description.to_s
              if association.options && association.options[:restrict_to_only]
                desc += "." unless desc =~ /\.\s*\z/
                desc += "  Restricted to queries using the #{md_inline_code("only")} parameter."
                desc.strip!
              end

              buffer << md_inline_code(association.name) + " | " + link + " | " + desc + "\n"
            end

            output << "\n"
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:presenter][:markdown] =
  Brainstem::ApiDocs::Formatters::Markdown::PresenterFormatter.method(:call)
