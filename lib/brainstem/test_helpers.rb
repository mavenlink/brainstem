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
    # Selecting an item from a collection by it's id
    #   expect(brainstem_data.users.by_id(235).name).to eq('name')
    #
    # Getting an array of all ids of in a collection without map
    #   expect(brainstem_data.users.ids).to include(1)
    #
    # Accessing the keys of a collection
    #   expect(brainstem_data.users.first.keys).to =~ %w(id name email address)
    #
    # Using standard array methods on a collection
    #   expect(brainstem_data.users.first.name).to eq('name')
    #   expect(brainstem_data.users[2].name).to eq('name')
    #
    def brainstem_data
      BrainstemDataHelper.new(response.body)
    end

    class BrainstemDataHelper
      def initialize(response_body)
        @json = JSON.parse(response_body)
      end

      def results
        BrainstemHelperCollection.new(@json['results'].map { |ref| @json[ref['key']][ref['id']] })
      end

      def method_missing(name)
        data = @json[name.to_s].try(:values)
        BrainstemHelperCollection.new(data) unless data.nil?
      end

      private

      class BrainstemHelperCollection < Array
        def initialize(collection)
          collection.each do |item|
            self << BrainstemHelperItem.new(item)
          end
        end

        def ids
          map { |item| item.id }
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

        def keys
          @data.keys
        end

        def method_missing(name)
          @data[name.to_s]
        end
      end
    end
  end
end
