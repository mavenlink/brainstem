# Brainstem

Brainstem is designed to power rich APIs in Rails or Sinatra. The Brainstem gem provides a framework for converting
ActiveRecord objects into structured JSON. Brainstem Presenters allow easy application of user-requested sorts, filters,
and association loads, allowing for simpler implementations, fewer requests, and smaller responses.

## Why Brainstem?

* Seperate business and presentation logic with Presenters.
* Version your Presenters for consistency as your API evolves.
* Expose end-user selectable filters and sorts.
* Whitelist your existing scopes to act as API filters for your users.
* Allow users to load multiple objects, with their associations, in a single request, reducing the number of requests needed to get the job done.  This is especially helpful for building speedy mobile applications.
* Prevent data duplication by pulling associations into top-level hashes.
* Easy integration with Backbone.js.  "It's like Ember.Data for Backbone.js!"

## Installation

Add this line to your application's Gemfile:

    gem 'brainstem'

## Usage

Create a class that inherits from Brainstem::Presenter, named after the model that you want to present. For example:

    class WidgetPresenter < Brainstem::Presenter
      presents "Widget"

      # Available sort orders to expose through the API
      sort_order :popularity, "widgets.popularity"
      sort_order :updated_at, "widgets.updated_at"

      # Default sort order to apply
      default_sort_order "updated_at:desc"

      # Optional filter that delegates to the Widget model `popular` scope
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

Once you've created a presenter like the one above, pass requests through to the presenter in your controller.

    class Api::WidgetsController < ActionController::Base
      include Brainstem::ControllerMethods

      def index
        render :json => present("widgets") { Widgets.visible_to(current_user) }
      end
    end

Requests can have includes, filters, and sort orders.

    GET /api/widgets.json?include=features&sort_order=popularity:desc&location_name=san+francisco

Responses will look like the following:

    {
      count: 5,  # Total number of results that matched the query.
      results: [{ key: "widgets", id: "2" }, { key: "widgets", id: "10" }],  # A lookup table to top-level keys.  Necessary
                                                                             # because some objects can have associations of
                                                                             # the same type as themselves.
      widgets: {
        "10": { id: "10", name: "disco ball", feature_ids: ["5"], popularity: 85 },
        "2": { id: "2", name: "flubber", feature_ids: ["6", "12"], popularity: 100 }
      },
      features: {
        "5": { id: "5", name: "shiny" },
        "6": { id: "6", name: "bouncy" },
        "12": { id: "12", name: "physically impossible" }
      }
    }

For more detailed examples, see the documentation for methods on {Brainstem::Presenter} and our detailed [Rails example application].

## Consuming a Brainstem API

APIs presented with Brainstem are just JSON APIs, so they can be consumed by just about any language.  As Brainstem evolves, we hope that
people will contributed consumption libraries in various languages.

### Brainstem and Backbone.js

If you're already using Backbone.js, integrating with a Brainstem API is super simple.  Just use the [brainstem-js] gem (or its JavaScript contents)
to interface with your API from JavaScript.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request (`git pull-request`)

## License

Brainstem was created by Mavenlink, Inc. is available under the MIT License.
