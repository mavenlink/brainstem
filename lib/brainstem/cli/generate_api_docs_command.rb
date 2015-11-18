require 'brainstem/cli/abstract_command'
require 'brainstem/api_docs'
require 'brainstem/api_docs/exceptions'
require 'brainstem/api_docs/builder'

sinks_path = File.expand_path('../../api_docs/sinks/**/*.rb', __FILE__)
formatters_path = File.expand_path('../../api_docs/formatters/**/*.rb', __FILE__)
Dir.glob(sinks_path).each { |f| require f }
Dir.glob(formatters_path).each { |f| require f }

module Brainstem
  module CLI
    class GenerateApiDocsCommand < AbstractCommand

      def call
        ensure_sink_specified!
        construct_builder!
        present_atlas!
      end


      def default_options
        {
          sink: {
            options: {},
          },

          builder: {
            args_for_introspector: {
              base_presenter_class: ::Brainstem::ApiDocs.method(:base_presenter_class),
              base_controller_class: ::Brainstem::ApiDocs.method(:base_controller_class),
            },

            args_for_atlas: {
              controller_matches: [],
            },
          },
        }
      end


      attr_accessor :builder


      def construct_builder!
        @builder = Brainstem::ApiDocs::Builder.new(builder_options)
      end


      def present_atlas!
        sink_method.call(sink_options) << builder.atlas
      end



      def ensure_sink_specified!
        raise Brainstem::ApiDocs::NoSinkSpecifiedException unless sink_method
      end


      def sink_method
        @sink_method ||= options[:sink][:method]
      end


      def builder_options
        @builder_options ||= options[:builder]
      end


      def sink_options
        @sink_options ||= options[:sink][:options]
      end


      def option_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: generate [options]"

          opts.on('-m', '--multifile-presenters-and-controllers',
                  'dumps presenters and controllers to separate files a la '\
                  'Mavenlink API docs.') do |o|
            options[:sink][:method] = \
              Brainstem::ApiDocs::Sinks::ControllerPresenterMultifileSink.method(:new)
          end


          opts.on('--host-env-file=PATH', "path to host app's entry file") do |o|
            options[:builder][:args_for_introspector][:rails_environment_file] = o
          end


          opts.on('--base-presenter-class=CLASS', "which class to look up presenters on") do |o|
            options[:builder][:args_for_introspector][:base_presenter_class] = o
          end


          opts.on('--base-controller-class=CLASS', "which class to look up controllers on") do |o|
            options[:builder][:args_for_introspector][:base_controller_class] = o
          end


          opts.on('--controller-matches=MATCH',
                  'a case-sensitive regexp used to winnow the list of '\
                  'controllers. It is matched against the constant, not '\
                  'underscored name of the controller. Specifying multiple '\
                  'performs a logical AND between Regexen.') do |o|
            # Trim slashes on passed MATCH.
            matcher = Regexp.new(o.gsub(/(\A\/)|(\/\z)/, ''), 'i')
            options[:builder][:args_for_atlas][:controller_matches].push(matcher)
          end


          opts.on('--markdown', 'use markdown format') do |o|
            options[:sink][:options][:format] = :markdown
          end
        end
      end
    end
  end
end
