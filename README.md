# Brainstem

Brainstem is designed to power rich APIs in Rails. The Brainstem gem provides a presenter library that handles converting ActiveRecord objects into structured JSON and a set of API abstractions that allow users to request sorts, filters, and association loads, allowing for simpler implementations, fewer requests, and smaller responses.

## Why Brainstem?

* Seperate business and presentation logic with Presenters.
* Version your Presenters for consistency as your API evolves.
* Expose end-user selectable filters and sorts.
* Whitelist your existing scopes to act as API filters for your users.
* Allow users to side-load multiple objects, with their associations, in a single request, reducing the number of requests needed to get the job done.  This is especially helpful for building speedy mobile applications.
* Prevent data duplication by pulling associations into top-level hashes, easily indexable by ID.
* Easy integration with Backbone.js.  "It's like Ember Data for Backbone.js!"

## Installation

Add this line to your application's Gemfile:

    gem 'brainstem'

## Usage

Create a class that inherits from Brainstem::Presenter, named after the model that you want to present, and preferrably versioned in a module. For example:

    module Api
	  module V1
	    class WidgetPresenter < Brainstem::Presenter
	      presents "Widget"
	
	      # Available sort orders to expose through the API
	      sort_order :updated_at, "widgets.updated_at"
	      sort_order :created_at, "widgets.created_at"
	
	      # Default sort order to apply
	      default_sort_order "updated_at:desc"
	
	      # Optional filter that delegates to the Widget model :popular scope, 
	      # which should take one argument of true or false.
	      filter :popular
	
	      # Optional filter that applies a lambda.
	      filter :location_name do |scope, location_name|
	        scope.joins(:locations).where("locations.name = ?", location_name)
	      end
	
	      # Filter with an overridable default that runs on all requests.
	      filter :include_legacy_widgets, :default => false do |scope, bool|
	        bool ? scope : scope.without_legacy_widgets
	      end
	
	      # Return a ruby hash that can be converted to JSON
	      def present(widget)
	        {
	            :name           => widget.name,
	            :legacy         => widget.legacy?,
	            :updated_at     => widget.updated_at,
	            :created_at     => widget.created_at,
	            # Associations can be included by request
	            :features       => association(:features),
	            :location       => association(:location)
	        }
	      end
	    end
	  end
	end

Once you've created a presenter like the one above, pass requests through from your controller.

    class Api::WidgetsController < ActionController::Base
      include Brainstem::ControllerMethods

      def index
        render :json => present("widgets") { Widgets.visible_to(current_user) }
      end
    end

The scope passed to `present` could contain any starting conditions that you'd like.  Requests can have includes, filters, and sort orders.

    GET /api/widgets.json?include=features&sort_order=popularity:desc&location_name=san+francisco

Responses will look like the following:

    {
      # Total number of results that matched the query.
      count: 5,
      
      # A lookup table to top-level keys.  Necessary
      # because some objects can have associations of
      # the same type as themselves.
      results: [
        { key: "widgets", id: "2" },
        { key: "widgets", id: "10" }
      ],
      
      # Serialized models with any requested associations, keyed by ID.

      widgets: {
        "10": {
          id: "10",
          name: "disco ball",
          feature_ids: ["5"],
          popularity: 85,
          location_id: "2"
        },
        
        "2": {
       	  id: "2",
       	  name: "flubber",
       	  feature_ids: ["6", "12"],
       	  popularity: 100,
       	  location_id: "2"
       	}
      },

      features: {
        "5": { id: "5", name: "shiny" },
        "6": { id: "6", name: "bouncy" },
        "12": { id: "12", name: "physically impossible" }
      }
    }

You may want to setup an initializer in `config/initializers/brainstem.rb` like the following:

    Brainstem.default_namespace = :v1
 
    module Api
	  module V1
	    module Helper
	      def current_user
	        # However you get your current user.
	      end
	    end
	  end
	end
	Brainstem::Presenter.helper(Api::V1::Helper)
	
	require 'api/v1/widget_presenter'
	require 'api/v1/feature_presenter'
	require 'api/v1/location_presenter'
	# ...
	
	# Or you could do something like this:
	#  Dir[Rails.root.join("lib/api/v1/*_presenter.rb").to_s].each { |p| require p }

For more detailed examples, please see the documentation for methods on {Brainstem::Presenter} and our detailed [Rails example application](https://github.com/mavenlink/brainstem-demo-rails).

## Consuming a Brainstem API

APIs presented with Brainstem are just JSON APIs, so they can be consumed with just about any language.  As Brainstem evolves, we hope that people will contributed consumption libraries in various languages.

### The Results Array

    {
      results: [
        { key: "widgets", id: "2" }, { key: "widgets", id: "10" }
      ],
      
      widgets: {
        "10": {
          id: "10",
          name: "disco ball",
          …


Brainstem returns objects as top-level hashes and provides a `results` array of `key` and `id` objects for finding the returned data in those hashes.  The reason that we use the `results` array is two-fold: 1st) it provides order outside of the serialized objects so that we can provide objects keyed by ID, and 2nd) it allows for polymorphic responses and for objects that have associations of their own type (like posts and replies or tasks and sub-tasks).

### Brainstem and Backbone.js

If you're already using Backbone.js, integrating with a Brainstem API is super simple.  Just use the [Brainstem.js](https://github.com/mavenlink/brainstem-js) gem (or its JavaScript contents) to access your relational Brainstem API from JavaScript.

## Contributing

1. Fork Brainstem or Brainstem.js
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request (`git pull-request`)

## License

Brainstem and Brainstem.js were created by Mavenlink, Inc. and are available under the MIT License.
