require 'active_support/inflector/inflections'
require 'brainstem/api_docs/abstract_collection'
require 'brainstem/api_docs/presenter'
require 'brainstem/concerns/formattable'

module Brainstem
  module ApiDocs
    class PresenterCollection < AbstractCollection
      include Concerns::Formattable

      def valid_options
        super | [ :presenter_constant_lookup_method ]
      end

      attr_writer :presenter_constant_lookup_method

      #
      # Finds or creates a presenter with the given target class and appends it to the
      # members list if it is new.
      #
      def find_or_create_from_target_class(target_class)
        find_by_target_class(target_class) ||
          create_from_target_class(target_class)
      end
      alias_method :find_or_create_by_target_class,
                     :find_or_create_from_target_class

      #
      # Finds a presenter for the given class
      #
      def find_by_target_class(target_class)
        find { |p| p.target_class == target_class }
      end

      #
      # Creates a new +Presenter+ wrapper and appends it to the collection. If
      # the constant lookup for the actual presenter class fails, returns nil.
      #
      def create_from_target_class(target_class)
        ::Brainstem::ApiDocs::Presenter.new(atlas,
          target_class: target_class,
          const:        target_class_to_const(target_class)
        ).tap { |p| self.<< p }
      rescue KeyError
        nil
      end

      def find_or_create_from_presenter_collection(target_class, const)
          find_by_target_class(target_class) ||
            create_from_presenter_collection(target_class, const)
      end
      alias_method :find_or_create_by_presenter_collection,
                     :find_or_create_from_presenter_collection

      def create_from_presenter_collection(target_class, const)
        ::Brainstem::ApiDocs::Presenter.new(atlas,
          target_class: target_class,
          const:        const
        ).tap { |p| self.<< p }
      end

      #########################################################################
      private
      #########################################################################

      #
      # Converts a target class into a presenter constant. Raises an error
      # if not found.
      #
      def target_class_to_const(target_class)
        presenter_constant_lookup_method.call(target_class.to_s)
      end

      #
      # A callable method by which presenter constants can be looked up from
      # their human name.
      #
      # In future, it might be worth unifying this method with `find_by_class`
      # to reduce total surface.
      #
      def presenter_constant_lookup_method
        @presenter_constant_lookup_method ||= Brainstem.presenter_collection.presenters.method(:fetch)
      end

    end
  end
end
