# This is a very simple DSL that makes generating a markdown document a bit
# easier.

module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        module Helper
          def md_h1(text)
            "# #{text}\n\n"
          end


          def md_h2(text)
            "## #{text}\n\n"
          end


          def md_h3(text)
            "### #{text}\n\n"
          end


          def md_h4(text)
            "#### #{text}\n\n"
          end


          def md_h5(text)
            "##### #{text}\n\n"
          end


          def md_strong(text)
            "**#{text}**"
          end


          def md_hr
            "-----\n\n"
          end


          def md_p(text)
            text + "\n\n"
          end


          def md_code(text, lang = "")
            "```#{lang}\n#{text}\n```\n\n"
          end


          def md_inline_code(text)
            "`#{text}`"
          end


          def md_ul(&block)
            (instance_eval(&block) || "") + "\n\n"
          end


          def md_li(text, indent_level = 0)
            "#{' ' * (indent_level * 4)}- #{text}\n"
          end


          def md_a(text, link)
            "[#{text}](#{link})"
          end


          def md_inline_type(type, item_type = nil)
            return "" if type.blank?

            text = type.to_s.capitalize
            text += "<#{item_type.to_s.capitalize}>" if item_type.present?
            " (#{md_inline_code(text)})"
          end


          def md_associations_table(presenter, options = {})
            return "" if presenter.valid_associations.empty?

            output = md_h5("Associations")
            output << "Association Name | Associated Class | Description\n"
            output << " --------------  |  --------------  |  ----------\n"

            output << presenter.valid_associations.inject("") do |buffer, (_, association)|
              if options[:associations_as_link] && (link = presenter.link_for_association(association))
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
            output
          end
        end
      end
    end
  end
end
