require 'brainstem/cli/abstract_command'
require 'brainstem/api_docs'
require 'brainstem/api_docs/exceptions'
require 'brainstem/api_docs/builder'

#
# Require all sinks and formatters.
#
sinks_path = File.expand_path('../../api_docs/sinks/**/*.rb', __FILE__)
formatters_path = File.expand_path('../../api_docs/formatters/**/*.rb', __FILE__)
Dir.glob(sinks_path).each { |f| require f }
Dir.glob(formatters_path).each { |f| require f }

#
# The GenerateApiDocsCommand is responsible for the construction and
# intermediation of the two primary components of automatic API doc generation.
#
# It instantiates both a +Builder+, which is responsible for introspecting and
# validation of the host application, and also passes the +Builder+-generated
# data structure to the +Sink+, which is responsible for serializing the data
# structure to some store (likely transforming the data along the way).
#
module Brainstem
  module CLI
    class GenerateApiDocsCommand < AbstractCommand


      def call
        ensure_sink_specified!
        construct_builder!
        present_atlas!
      end


      def default_sink_method
        Brainstem::ApiDocs::Sinks::ControllerPresenterMultifileSink.method(:new)
      end


      def default_options
        {
          sink: {
            method: default_sink_method,
            options: {}
          },

          builder: {
            args_for_atlas: { controller_matches: [] },
            args_for_introspector: {
              base_presenter_class:  ::Brainstem::ApiDocs.method(:base_presenter_class),
              base_controller_class: ::Brainstem::ApiDocs.method(:base_controller_class),
              base_application_class: ::Brainstem::ApiDocs.method(:base_application_class),
            },
          },
        }
      end


      attr_accessor :builder


      #########################################################################
      private
      #########################################################################

      #
      # Instantiates a builder, passing the relevant options to it.
      #
      def construct_builder!
        @builder = Brainstem::ApiDocs::Builder.new(builder_options)
      end


      #
      # Hands the atlas over to the sink.
      #
      def present_atlas!
        sink_method.call(sink_options) << builder.atlas
      end


      #
      # Raises an error unless the user specified a destination for the output.
      #
      def ensure_sink_specified!
        raise Brainstem::ApiDocs::NoSinkSpecifiedException unless sink_method
      end


      #
      # Utility method for retrieving the sink.
      #
      def sink_method
        @sink_method ||= options[:sink][:method]
      end


      #
      # Utility method for retrieving builder options.
      #
      def builder_options
        @builder_options ||= options[:builder]
      end


      #
      # Utility method for retrieving sink options.
      #
      def sink_options
        @sink_options ||= options[:sink][:options]
      end


      #
      # Defines the option parser for this command.
      #
      # @return [OptionParser] the option parser that should mutate the
      #   +options+ hash.
      #
      def option_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: generate [options]"

          opts.on('-m', '--multifile-presenters-and-controllers',
                  'dumps presenters and controllers to separate files (default)') do |o|
            options[:sink][:method] = \
              Brainstem::ApiDocs::Sinks::ControllerPresenterMultifileSink.method(:new)
          end


          opts.on('--host-env-file=PATH', "path to host app's entry file") do |o|
            options[:builder][:args_for_introspector][:rails_environment_file] = o
          end


          opts.on('-o RELATIVE_DIR', '--output-dir=RELATIVE_DIR',
                  'specifies directory which to output if relevant') do |o|
            options[:sink][:options][:write_path] = o
          end


          opts.on('--base-presenter-class=CLASS', "which class to look up presenters on") do |o|
            options[:builder][:args_for_introspector][:base_presenter_class] = o
          end


          opts.on('--base-controller-class=CLASS', "which class to look up controllers on") do |o|
            options[:builder][:args_for_introspector][:base_controller_class] = o
          end


          opts.on('--base-application-class=CLASS', "which class to look up routes on") do |o|
            options[:builder][:args_for_introspector][:base_application_class] = o
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
