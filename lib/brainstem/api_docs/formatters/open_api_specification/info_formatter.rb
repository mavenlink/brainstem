require 'brainstem/api_docs/formatters/abstract_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        class InfoFormatter < AbstractFormatter

          #
          # Declares the options that are permissable to set on this instance.
          #
          def valid_options
            super | [
              :version
            ]
          end

          attr_accessor :output,
                        :version

          def initialize(options = {})
            self.output = ActiveSupport::HashWithIndifferentAccess.new

            super options
          end

          def call
            format_swagger_object!
            format_info_object!
            output
          end


          #####################################################################
          private
          #####################################################################


          def format_swagger_object!
            output.merge!( swagger_object )
          end

          def format_info_object!
            output.merge!( 'info' => info_object )
          end

          def swagger_object
            {
              'swagger'  => '2.0',
              'host'     => host,
              'basePath' => base_path,
              'schemes'  => schemes,
              'consumes' => consumes,
              'produces' => produces
            }.with_indifferent_access.reject { |_, v| v.blank? }
          end

          def info_object
            {
              'version'        => version.presence || '1.0',
              'title'          => title,
              'description'    => description,
              'termsOfService' => terms_of_service,
              'contact'        => contact_object,
              'license'        => license_object
            }.with_indifferent_access.reject { |_, v| v.blank? }
          end


          #####################################################################
          # Override with custom values                                       #
          #####################################################################


          def host
            'petstore.swagger.io'
          end

          def base_path
            '/v2'
          end

          def schemes
            %w(https)
          end

          def consumes
            %w(application/json)
          end

          def produces
            %w(application/json)
          end

          def title
            'Petstore'
          end

          def description
            <<-DESC.strip_heredoc
              This is a sample server Petstore server. You can find out more about Swagger at
              [http://swagger.io](http://swagger.io) or on [irc.freenode.net, #swagger](http://swagger.io/irc/).
              For this sample, you can use the api key `special-key` to test the authorization filters.
            DESC
          end

          def terms_of_service
            'http://swagger.io/terms/'
          end

          def contact_object
            {
              'name'  => 'Pet Store Support',
              'url'   => 'https://swagger.io/support/',
              'email' => 'apiteam@swagger.io',
            }
          end

          def license_object
            {
              'name' => 'Apache 2.0',
              'url'  => 'http://www.apache.org/licenses/LICENSE-2.0.html',
            }
          end
        end
      end
    end
  end
end


Brainstem::ApiDocs::FORMATTERS[:info][:oas] = \
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::InfoFormatter.method(:call)
