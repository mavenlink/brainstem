# Brainstem

The Brainstem gem provides a framework for converting model objects into JSON-compatible hashes. Presenters that inherit from the Brainstem class are able to apply sorting and filtering options, either by default or as requested by end-users of the API. Presenters also handle all of the work of loading and presenting associations of the objects that are being requested, allowing simpler implementations, fewer requests, and smaller responses.

## Installation

Add this line to your application's Gemfile:

    gem 'brainstem'

## Usage

Create a class that inherits from Brainstem::Presenter, named after the model you want to present. For example:

    class UserPresenter < Brainstem::Presenter

      # Return a ruby hash that can be converted to JSON
      def present(user)
        {
          :id => user.id,
          # Associations can be included by request
          :friends => association(:friends)
        }
      end

      # Optional filter that delegates to the User model `confirmed` scope
      filter :confirmed

      # Optional sort order that may be requested
      sort_order :popularity, "users.friends_count"

      # Default sort order to apply
      default_sort_order "created_at:desc"

    end

Once you've created a presenter like the one above, pass requests through to the presenter in your controller.

    class Api::UserController < ActionController::Base
      include Brainstem::ControllerMethods

      def index
	render :json => present("users") { User.visible_to(current_user) }
      end
    end

Requests can have includes, filters, and sort orders.

    GET /api/users?include=friends&sort_order=popularity&filter=confirmed:true

For more detailed examples, see the documentation for methods on {Brainstem::Presenter}.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request (`git pull-request`)
