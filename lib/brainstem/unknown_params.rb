module Brainstem
  class UnknownParams < StandardError
    attr_reader :unknown_params

    def initialize(message = "Unidentified Params sighted", unknown_params = [])
      @unknown_params = unknown_params
      super(message)
    end
  end
end
