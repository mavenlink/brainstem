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
        end
      end
    end
  end
end
