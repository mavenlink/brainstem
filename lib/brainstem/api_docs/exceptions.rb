module Brainstem
  module ApiDocs
    class IncorrectIntrospectorForAppException  < StandardError; end
    class InvalidIntrospectorError              < StandardError; end
    class InvalidAtlasError                     < StandardError; end
    class NoSinkSpecifiedException              < StandardError; end
  end
end
