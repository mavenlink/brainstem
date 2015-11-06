require 'brainstem/concerns/optional'

module Brainstem
  module ApiDocs
    module Sinks
      class AbstractSink
        include Concerns::Optional


        #
        # Primary method for putting the atlas into the sink.
        #
        # @param [Brainstem::ApiDocs::Atlas] the atlas
        #
        def <<(atlas)
          raise NotImplementedError
        end


        #######################################################################$
        private
        ########################################################################


        #
        # Whitelist of options which can be set on an instance.
        #
        # @return [Array<Symbol>] valid options
        #
        def valid_options
          []
        end

      end
    end
  end
end
