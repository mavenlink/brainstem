module Brainstem
  # Helpers for easing the testing of brainstem responses in controller specs
  #
  # To use, add the following to you spec_helper file:
  #
  #   require 'brainstem/test_helpers'
  #   Rspec.configure { |config| config.include Brainstem::TestHelpers, :type => :controller }
  #
  module TestHelpers
    # Use brainstem_data in your controller specs to easily access
    # Brainstem JSON data payloads and their attributes
    #
    # Examples:
    #
    # Assume user is the model and name is an attribute
    #
    # If there are multiple users, using a singular method will return the first one
    #   expect(brainstem_data.user.name).to eq('name')
    #
    # A pluralized model name returns the collection
    #   expect(brainstem_data.users.ids).to include(1)
    #
    # You can use the index operator on a collection
    #   expect(brainstem_data.users[2].title).to eq('title')
    #
    def brainstem_data
      BrainstemDataHelper.new(response.body)
    end

    class BrainstemDataHelper
      def initialize(response_body)
        @json = JSON.parse(response_body)
      end

      def method_missing(name)
        if plural?(name)
          build_collection(name)
        elsif singular?(name)
          build_item(name)
        end
      end

      private

      def build_collection(name)
        data = @json[name.to_s].try(:values)
        BrainstemHelperCollection.new(data) unless data.nil?
      end

      def build_item(name)
        data = @json[name.to_s.pluralize].try(:values).try(:first)
        BrainstemHelperItem.new(data) unless data.nil?
      end

      def plural?(name)
        name.to_s.pluralize == name.to_s
      end

      def singular?(name)
        name.to_s.singularize == name.to_s
      end

      class BrainstemHelperCollection < Array
        def initialize(collection)
          collection.each do |item|
            self << BrainstemHelperItem.new(item)
          end
        end

        def ids
          map { |item| item.id.to_i }
        end

        def by_id(id)
          detect { |item| item.id == id.to_s }
        end

        def method_missing(name)
          map { |item| item.send(name.to_s.singularize) }
        end
      end

      class BrainstemHelperItem
        def initialize(data)
          @data = data
        end

        def method_missing(name)
          @data[name.to_s]
        end

        def keys
          @data.keys
        end
      end
    end
  end
end
