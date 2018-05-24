#
# This module is used in lieu of an dependency on optional kwargs. Any symbol
# included in the array of +#valid_options+ will be whitelisted from passed
# options and sent to the instance on initialization.
#
# In this simple way, we can make classes accept options, whitelist which
# are acceptable, and set them without having to manually extend our
# initializer.
#
# In order to use this, your constructor must have an argument named +options+
# that defaults to an empty hash. Additionally, for each option you define, you
# should define an accessor or at least a writer.
#
# You may also implement a +#valid_options+ method. It is recommended that you
# make this the union of the superclass's +valid_options+ method and this
# class's options so that inherited options are preserved:
#
# @example
#     def valid_options
#       super | [ :your_options_here ]
#     end
#
module Brainstem
  module Concerns
    module Optional

      #
      # The options that should be extracted and sent to the class on
      # initialization.
      #
      # @return [Array<Symbol>] valid options
      #
      def valid_options
        [ ]
      end

      def initialize(options = {})
        options.slice(*valid_options).each {|k, v| self.send("#{k}=", v) }
      end
    end
  end
end
