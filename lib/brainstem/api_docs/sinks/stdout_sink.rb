require 'brainstem/api_docs/sinks/abstract_sink'

module Brainstem
  module ApiDocs
    module Sinks
      class StdoutSink < AbstractSink

        #
        # Writes the output using stdout.puts.
        #
        def <<(output)
          puts_method.call(output)
        end

        ########################################################################
        private
        ########################################################################

        def valid_options
          super | [ :puts_method ]
        end

        #
        # Storage for holding the writing method.
        #
        attr_writer :puts_method

        #
        # Callable method for writing data to a buffer (by default stdout).
        #
        # @return [Proc] a method which writes data to a buffer when called.
        #
        def puts_method
          @puts_method ||= $stdout.method(:puts)
        end
      end
    end
  end
end
