module Brainstem
  class ValidationError < StandardError
    attr_reader :unknown_params, :malformed_params

    def initialize(message = "Invalid params sighted", unknown_params = [], malformed_params = [])
      @unknown_params   = unknown_params
      @malformed_params = malformed_params

      super(message)
    end
  end
end
