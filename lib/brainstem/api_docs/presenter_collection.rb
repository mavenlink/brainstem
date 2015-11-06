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
      # Finds or creates a presenter with the given name and appends it to the
      # members list if it is new.
      #
      def find_or_create_from_presents(presents)
        find_by_presents(presents) || create_from_presents(presents)
      end
      alias_method :find_or_create_by_presents, :find_or_create_from_presents


      #
      # Finds a presenter with the given human name.
      #
      def find_by_presents(presents)
        find { |p| p.presents == presents }
      end


      #
      # Creates a new +Presenter+ wrapper and appends it to the collection. If
      # the constant lookup for the actual presenter class fails, returns nil.
      #
      def create_from_presents(presents)
        ::Brainstem::ApiDocs::Presenter.new(
          presents: presents,
          const:    presenter_name_to_const(presents)
        ).tap { |p| self.<< p }
      rescue KeyError
        nil
      end


      #########################################################################
      private
      #########################################################################

      #
      # Converts a 'presents' string into a presenter constant. Raises an error
      # if not found.
      #
      def presenter_name_to_const(name)
        presenter_constant_lookup_method.call(name.to_s.classify)
      end


      #
      # A callable method by which presenter constants can be looked up from
      # their human name.
      #
      def presenter_constant_lookup_method
        @presenter_constant_lookup_method ||= \
          Brainstem.presenter_collection.presenters.method(:fetch)
      end


    end
  end
end
