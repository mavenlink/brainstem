require 'brainstem/api_docs'
require 'brainstem/api_docs/exceptions'
require 'brainstem/concerns/optional'

#
# A formatter is fundamentally just a function that, when +#call+ed, accepts an
# atlas and returns the whole or portion of its data in a readable format.
#
# There are (informally) several types of formatters, and you should select
# among them appropriately when developing your own:
#
# 1. Entity
#
#       Turns a single data entity into its formatted version. For example, if
#       formatting a Post object, call this formatter a
#       +<Format>PostFormatter+.
#
# 2. Collection
#
#       Turns a collection of formatted data entities into a single unit.
#       Usually this will involve concatenating and/or rejecting inappropriate
#       output. For example, if you have a collection of Markdown strings from
#       the MarkdownPostFormatter, you might want to generate the whole section
#       of documentation by using a +MarkdownPostCollectionFormatter+.
#
# 3. Aggregate
#
#       A combination of entity and collection formatters. Knows how to turn a
#       collection of unformatted entities into a single formatted document.
#       Not as composable as the two used seperately, but far simpler. This
#       should be named +MarkdownAggregatePostFormatter+.
#
# At the time of writing, there is no actual requirement to use these naming
# conventions, but it is highly recommended for clarity of purpose.
#
module Brainstem
  module ApiDocs
    module Formatters
      class AbstractFormatter
        include Concerns::Optional

        #
        # Convenience class method for instantiating and calling.
        #
        def self.call(*args)
          new(*args).call
        end


        def initialize(*args)
          super args.last || {}
        end


        #
        # Override to transform atlas data into serialized format.
        #
        def call
          raise NotImplementedError
        end
      end
    end
  end
end
