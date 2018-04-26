require 'brainstem/api_docs/formatters/abstract_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        class SecurityDefinitionsFormatter < AbstractFormatter

          attr_accessor :output

          def initialize(options = {})
            self.output = ActiveSupport::HashWithIndifferentAccess.new

            super options
          end

          def call
            format_basic_auth_definitions!
            format_apikey_auth_definitions!
            format_oauth_definitions!
            format_security_object!

            output
          end


          #####################################################################
          private
          #####################################################################


          def format_basic_auth_definitions!
            add_security_definition(basic_auth_definitions)
          end

          def format_apikey_auth_definitions!
            add_security_definition(apikey_auth_definitions)
          end

          def format_oauth_definitions!
            add_security_definition(oauth_definitions)
          end

          def format_security_object!
            return if security_object.blank?

            output.merge!('security' => security_object)
          end

          def add_security_definition(security_definition)
            return if security_definition.blank?

            output['securityDefinitions'] ||= {}
            output['securityDefinitions'].merge!(security_definition)
          end

          #####################################################################
          # Override with custom values                                       #
          #####################################################################


          def basic_auth_definitions
            {}
          end

          def apikey_auth_definitions
            {
              'api_key' => {
                'type' => 'apiKey',
                'name' => 'api_key',
                'in'   => 'header'
              }
            }
          end

          def oauth_definitions
            {
              'petstore_auth' => {
                'type'             => 'oauth2',
                'authorizationUrl' => 'http://petstore.swagger.io/oauth/dialog',
                'flow'             => 'implicit',
                'scopes'           => {
                  'write:pets' => 'modify pets in your account',
                  'read:pets'  => 'read your pets'
                }
              }
            }
          end

          def security_object
            {}
          end
        end
      end
    end
  end
end


Brainstem::ApiDocs::FORMATTERS[:security][:oas] = \
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::SecurityDefinitionsFormatter.method(:call)
