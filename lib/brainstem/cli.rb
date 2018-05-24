# Require all CLI commands.
Dir.glob(File.expand_path('../cli/**/*.rb', __FILE__)).each { |f| require f }
require 'brainstem/concerns/optional'

#
# General manager for CLI requests. Takes incoming user input and routes to a
# subcommand.
module Brainstem
  class Cli
    include Concerns::Optional

    EXECUTABLE_NAME = 'brainstem'

    #
    # Convenience for instantiating and calling the Cli object.
    #
    # @return [Brainstem::Cli] the created instance
    #
    def self.call(args, options = {})
      new(args, options).call
    end

    #
    # Creates a new instance of the Cli to respond to user input.
    #
    # Input is expected to be the name of the subcommand, followed by any
    # additional arguments.
    #
    def initialize(args, options = {})
      super options

      self._args              = args.dup.freeze
      self.requested_command  = args.shift
    end

    #
    # Routes to an application endpoint depending on given options.
    #
    # @return [Brainstem::Cli] the instance
    #
    def call
      if requested_command && commands.has_key?(requested_command)
        self.command_method = commands[requested_command].method(:call)
      end

      command_method.call(_args.drop(1))

      self
    end

    #
    # Holds a copy of the initial given args for debugging purposes.
    #
    attr_accessor :_args

    #
    # Storage for the extracted command.
    #
    attr_accessor :requested_command

    ################################################################################
    private
    ################################################################################

    #
    # A whitelist of valid options that can be applied to the instance.
    #
    # @returns [Array<String>]
    #
    def valid_options
      super | [
        :log_method
      ]
    end

    #
    # A basic routing table where the keys are the command to invoke, and where
    # the value is a callable object or class that will be called with the
    # +command_options+.
    #
    # @return [Hash] A hash of +'command' => Callable+
    #
    def commands
      { 'generate' => Brainstem::CLI::GenerateApiDocsCommand }
    end

    #
    # Retrieves the help text and subs any placeholder values.
    #
    def help_text
      @help_text ||= File.read(File.expand_path('../help_text.txt', __FILE__))
        .gsub('EXECUTABLE_NAME', EXECUTABLE_NAME)
    end

    #
    # Stores the method we should call to run the user command.
    #
    attr_writer :command_method

    #
    # Reader for the method to invoke. By default, will output the help text
    # when called.
    #
    # @return [Proc] An object responding to +#call+ that is used as the main
    # point execution.
    #
    def command_method
      @command_method ||= Proc.new do
        # By default, serve help.
        log_method.call(help_text)
      end
    end

    #
    # Stores the method we should use to log messages.
    #
    attr_writer :log_method

    #
    # Reader for the method to log. By default, will print to stdout when
    # called.
    #
    # We return a proc here because it's much tricker to make assertions
    # against stdout than it is to allow ourselves to inject a proc.
    #
    # @return [Proc] An object responding to +#call+ that is used to print
    # information.
    #
    def log_method
      @log_method ||= $stdout.method(:puts)
    end
  end
end
