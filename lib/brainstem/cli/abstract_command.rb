require 'optparse'

#
# A Command is a callable object that acts as an entrypoint into the
# application logic. It is responsible for translating given options into
# specific enquiries.
#
# Internally, it wraps an OptionParser instance returned through its
# +option_parser` method. The evaluation of this parser mutates the +options+
# hash. This is available to the +call+ method on the instance, which is the
# primary point of application logic execution.
#
module Brainstem
  module CLI
    class AbstractCommand

      #
      # Convenience method for instantiating the command and calling it.
      #
      # @return [Brainstem::CLI::AbstractCommand] the instance
      #
      def self.call(args = [])
        instance = new(args)
        instance.call
        instance
      end


      #
      # Returns a new instance of the command with options set.
      #
      def initialize(args = [])
        # TODO: These args are going to get gobbled up.
        self.args     = args
        self.options  = default_options
        extract_options!
      end


      #
      # Returns the hash of default options used as a base into which cli args
      # are merged.
      #
      def default_options
        {}
      end


      #
      # Kicks off execution of app-level code. Has available to it +options+,
      # which contains the options extracted from the command line.
      #
      def call
        raise NotImplementedError,
          "Override #call and implement your application logic."
      end


      #
      # Storage for given options.
      #
      attr_accessor :options


      #
      # Storage for passed, unparsed args.
      #
      attr_accessor :args


      #
      # Extracts command-line options for this specific command based on the
      # +OptionParser+ specified in +self.option_parser+.
      #
      # @return [Hash] the extracted command-line options
      #
      def extract_options!
        option_parser.order!(args)
      end


      #
      # An +OptionParser+ instance that specifies how options should be
      # extracted specific to this command.
      #
      # Available to this method is the +options+ method, which is the primary
      # method of communicating options to the +call+ method.
      #
      # @return [OptionParser] an instance of OptionParser
      # @see http://ruby-doc.org/stdlib-2.2.2/libdoc/optparse/rdoc/OptionParser.html
      #
      def option_parser
        raise NotImplementedError,
          "Must return an instance of OptionParser."
      end
    end
  end
end
