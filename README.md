# ApiPresenter

The API Presenter gem provides a framework for converting model objects into JSON-compatible hashes. Presenters that inherit from the ApiPresenter class are able to apply sorting and filtering options, either by default or as requested by end-users of the API. Presenters also handle all of the work of loading and presenting associations of the objects that are being requested, allowing fewer requests and smaller responses.

## Installation

Add this line to your application's Gemfile:

    gem 'api_presenter'

## Usage

Create a class that inherits from ApiPresenter::Base, named after the model you want to present. For example:

    class UserPresenter < ApiPresenter::Base

      # Return a ruby hash that can be converted to JSON
      def present(user)
        {
          :id => user.id,
          # Associations can be included by request
          :friends => association(:friends)
        }
      end

      # Optional filter that delegates to model scope
      filter :confirmed

      # Optional sort order that may be requested
      sort_order :popularity, "users.friends_count"

      # Optional sort order to apply automatically
      default_sort_order "created_at:desc"

    end

Once you've created a presenter like the one above, pass requests through to the presenter in your controller.

    class Api::UserController < ActionController::Base
      include ApiPresenter::ControllerMethods

      def index
        present("user"){ User.where(id: current_user.id) }
      end
    end

Requests can request includes, filters, and sort orders.

    GET /api/users?include=friends&sort_order=popularity&filter=confirmed:true

For more detailed examples, see [USAGE](USAGE.md).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request (`git pull-request`)
