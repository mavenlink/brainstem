require 'brainstem/concerns/optional'

#
# The Resolver is responsible for taking a non-ApiDocs class and turning it
# into an ApiDocs wrapper class (such as a Presenter, Controller, or Endpoint).
#
# It's useful for doing object lookups for associated objects where we only
# have the original class or constant to look up the relationship.
#
module Brainstem
  module ApiDocs
    class Resolver
      include Brainstem::Concerns::Optional

      def valid_options
        [
          :presenter_constant_lookup_method,
        ]
      end

      def initialize(atlas, options = {})
        self.atlas = atlas
        super options
      end

      attr_accessor :atlas,
                    :presenter_constant_lookup_method

      def find_by_class(klass)
        if klass == :polymorphic
          nil
        elsif klass < ActiveRecord::Base
          find_presenter_from_target_class(klass)
        end
      end

      #########################################################################
      private
      #########################################################################

      def find_presenter_from_target_class(klass)
        const = presenter_target_class_to_const(klass)
        atlas.presenters.find {|p| p.const == const }
      rescue
        nil
      end

      #
      # Converts a class into a presenter constant. Raises an error
      # if not found.
      #
      def presenter_target_class_to_const(target_class)
        presenter_constant_lookup_method.call(target_class.to_s)
      end

      #
      # A callable method by which presenter constants can be looked up from
      # their human name.
      #
      def presenter_constant_lookup_method
        @presenter_constant_lookup_method ||= Brainstem.presenter_collection.presenters.method(:fetch)
      end
    end
  end
end

