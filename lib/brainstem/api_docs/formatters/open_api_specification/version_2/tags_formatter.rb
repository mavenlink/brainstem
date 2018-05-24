require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          class TagsFormatter < AbstractFormatter
            include Helper

            #
            # Declares the options that are permissable to set on this instance.
            #
            def valid_options
              super | [
                :controllers,
                :ignore_tagging
              ]
            end

            attr_accessor :output,
                          :controllers,
                          :ignore_tagging

            def initialize(controllers, options = {})
              self.output         = ActiveSupport::HashWithIndifferentAccess.new
              self.controllers    = controllers
              self.ignore_tagging = false

              super options
            end

            def call
              return {} if ignore_tagging || controllers.blank?

              format_tags!
              format_tag_groups!
              output
            end

            #####################################################################
            private
            #####################################################################

            def format_tags!
              output.merge!( 'tags' => format_tags_data )
            end

            def format_tag_groups!
              return unless tag_groups_specified?(documentable_controllers)

              output.merge!( 'x-tagGroups' => format_tag_groups )
            end

            #####################################################################
            # Override                                                          #
            #####################################################################

            def documentable_controllers
              @documentable_controllers ||= controllers.
                select { |controller| !controller.nodoc? && controller.endpoints.only_documentable.any? }
            end

            def format_tags_data
              documentable_controllers
                .map { |controller| format_tag_data(controller) }
                .sort_by { |tag_data| tag_data[:name] }
            end

            def tag_groups_specified?(controllers)
              documentable_controllers.any? { |controller|
                controller.tag_groups.present?
              }
            end

            def format_tag_groups
              groups = Hash.new.tap do |result|
                documentable_controllers.each do |controller|
                  controller_tag = tag_name(controller)
                  controller_tag_groups = tag_groups(controller).presence || [controller_tag]

                  controller_tag_groups.each do |tag_group_name|
                    result[tag_group_name] ||= []
                    result[tag_group_name] << controller_tag
                  end
                end
              end

              groups.keys.sort.map do |tag_group_name|
                {
                  name: tag_group_name,
                  tags: groups[tag_group_name].sort
                }.with_indifferent_access
              end
            end

            def tag_name(controller)
              controller.tag.presence || format_tag_name(controller.name)
            end

            def tag_groups(controller)
              controller.tag_groups.presence
            end

            #
            # Returns formatted tag object for a given controller.
            #
            def format_tag_data(controller)
              {
                name:        tag_name(controller),
                description: format_description(controller.description),
              }.reject { |_, v| v.blank? }
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:tags][:oas_v2] =
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::TagsFormatter.method(:call)
