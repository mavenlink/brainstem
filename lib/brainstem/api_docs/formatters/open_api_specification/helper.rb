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

          def format_sentence(description)
            return '' if description.blank?

            desc = description.to_s.strip.tap { |desc| desc[0] = desc[0].upcase }
            desc += "." unless desc =~ /\.\s*\z/
            desc
          end

          def uncapitalize(description)
            return '' if description.blank?

            description.strip.tap { |desc| desc[0] = desc[0].downcase }
          end

          def type_and_format(type, item_type = nil)
            result = case type.to_s.downcase
              when 'array'
                { 'type' => 'array', 'items' => type_and_format(item_type.presence || 'string') }
              else
                TYPE_INFO[type.to_s]
            end
            result ? result.with_indifferent_access : nil
          end

          TYPE_INFO = {
            'string'   => { 'type' => 'string'                           },
            'boolean'  => { 'type' => 'boolean'                          },
            'integer'  => { 'type' => 'integer', 'format' => 'int32'	   },
            'long'     => { 'type' => 'integer', 'format' => 'int64'	   },
            'float'    => { 'type' => 'number',  'format' => 'float'     },
            'double'   => { 'type' => 'number',  'format' => 'double'    },
            'byte'     => { 'type' => 'string',  'format' => 'byte'      },
            'binary'   => { 'type' => 'string',  'format' => 'binary'    },
            'date'     => { 'type' => 'string',  'format' => 'date'      },
            'datetime' => { 'type' => 'string',  'format' => 'date-time' },
            'password' => { 'type' => 'string',  'format' => 'password'  },
            'id'       => { 'type' => 'integer', 'format' => 'int32'	   },
            'decimal'  => { 'type' => 'number',  'format' => 'float'     },
            'csv'      => { 'type' => 'string',  'collectionFormat' => 'csv'   },
            'ssv'      => { 'type' => 'string',  'collectionFormat' => 'ssv'   },
            'tsv'      => { 'type' => 'string',  'collectionFormat' => 'tsv'   },
            'pipes'    => { 'type' => 'string',  'collectionFormat' => 'pipes' },
          }
          private_constant :TYPE_INFO
        end
      end
    end
  end
end
