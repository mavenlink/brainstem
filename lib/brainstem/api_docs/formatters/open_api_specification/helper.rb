# This is a very simple DSL that makes generating a markdown document a bit
# easier.

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Helper
          def presenter_title(presenter)
            presenter.contextual_documentation(:title).presence ||
                presenter.target_class.underscore.singularize.titleize.strip
          end

          def format_http_method(endpoint)
            endpoint.http_methods.first.downcase
          end

          def format_tag_name(name)
            return name if name.blank?

            name.underscore.titleize.strip
          end

          def format_description(description)
            return if description.blank?

            desc = description.to_s.strip.capitalize
            desc += "." unless desc =~ /\.\s*\z/
            desc
          end

          # TODO: multi nested
          def type_and_format(type, item_type = nil)
            result = case type.to_s.downcase
              when 'array'
                { 'type' => 'array', 'items' => { 'type' => item_type.presence || 'string' } }
              else
                TYPE_INFO[type.to_s]
            end
            result ? result.dup.with_indifferent_access : nil
          end

          TYPE_INFO = {
            'string'       => { 'type' => 'string'                           },
            'boolean'      => { 'type' => 'boolean'                          },
            'integer'      => { 'type' => 'integer', 'format' => 'int32'	   },
            'long'         => { 'type' => 'integer', 'format' => 'int64'	   },
            'float'        => { 'type' => 'number',  'format' => 'float'     },
            'double'       => { 'type' => 'number',  'format' => 'double'    },
            'byte'         => { 'type' => 'string',  'format' => 'byte'      },
            'binary'       => { 'type' => 'string',  'format' => 'binary'    },
            'date'         => { 'type' => 'string',  'format' => 'date'      },
            'datetime'     => { 'type' => 'string',  'format' => 'date-time' },
            'password'     => { 'type' => 'string',  'format' => 'password'  },
            'id'           => { 'type' => 'integer', 'format' => 'int32'	   },
            'decimal'      => { 'type' => 'number',  'format' => 'float'     },
          }
          private_constant :TYPE_INFO
        end
      end
    end
  end
end
