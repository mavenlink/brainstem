module Brainstem
  class MalformedParams < StandardError
    attr_reader :malformed_params

    def initialize(message = "Malformed Params sighted", malformed_params = [])
      @malformed_params = malformed_params
      super(message)
    end
  end
end
