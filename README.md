# ApiPresenter

The API Presenter gem provides a framework for converting model objects into JSON-compatible hashes. Presenters that
inherit from the ApiPresenter class are able to apply sorting and filtering options, either by default or as requested
by end-users of the API. Presenters also handle all of the work of loading and presenting associations of the objects
that are being requested, allowing fewer requests and smaller responses.

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
          :friends => association(:friends)
        }
      end

      # Optional list of includes that may be requested
      allowed_includes(:friends => "friends")

      # Optional sort order that may be requested
      sort_order :popularity, "users.friends_count DESC"

      # Optional sort order to apply automatically
      default_sort_order "created_at DESC"

    end

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request (`git pull-request`)
