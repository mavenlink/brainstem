If you're upgrading from an older version of Brainstem, please see [Upgrading From The Pre 1.0 Brainstem](https://github.com/mavenlink/brainstem#upgrading-from-the-pre-10-brainstem) and the rest of this README.

# Brainstem

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/mavenlink/brainstem?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Build Status](https://travis-ci.org/mavenlink/brainstem.png)](https://travis-ci.org/mavenlink/brainstem)

Brainstem is designed to power rich APIs in Rails. The Brainstem gem provides a presenter library that handles
converting ActiveRecord objects into structured JSON and a set of API abstractions that allow users to request sorts,
filters, and association loads, allowing for simpler implementations, fewer requests, and smaller responses.

## Why Brainstem?

* Separate business and presentation logic with Presenters.
* Version your Presenters for consistency as your API evolves.
* Expose end-user selectable filters and sorts.
* Whitelist your existing scopes to act as API filters for your users.
* Allow users to side-load multiple objects, with their associations, in a single request, reducing the number of
  requests needed to get the job done.  This is especially helpful for building speedy mobile applications.
* Prevent data duplication by pulling associations into top-level hashes, easily indexable by ID.
* Easy integration with Backbone.js via [brainstem-js](https://github.com/mavenlink/brainstem-js).  "It's like Ember Data for Backbone.js!"

[Watch our talk about Brainstem from RailsConf 2013](http://www.confreaks.com/videos/2457-railsconf2013-introducing-brainstem-your-companion-for-rich-rails-apis)

## Installation

Add this line to your application's Gemfile:

    gem 'brainstem'

## Usage

### Make a Presenter

Create a class that inherits from Brainstem::Presenter, named after the model that you want to present, and preferrably
versioned in a module. For example `lib/api/v1/widget_presenter.rb`:

```ruby
module Api
  module V1
    class WidgetPresenter < Brainstem::Presenter
      presents Widget

      # Available sort orders to expose through the API
      sort_order :updated_at, "widgets.updated_at"
      sort_order :created_at, "widgets.created_at"

      # Default sort order to apply
      default_sort_order "updated_at:desc"

      # Optional filter that applies a lambda.
      filter :location_name do |scope, location_name|
        scope.joins(:locations).where("locations.name = ?", location_name)
      end

      # Filter with an overridable default. This will run on every request,
      # passing in `bool` as `false` unless a user has specified otherwise.
      filter :include_legacy_widgets, default: false do |scope, bool|
        bool ? scope : scope.without_legacy_widgets
      end

      # The top-level JSON key in which these presented records will be returned.
      # This is optional and defaults to the model's table name.
      brainstem_key :widgets

      # Specify the fields to be present in the returned JSON.
      fields do
        field :name, :string, "the Widget's name"
        field :legacy, :boolean, "true for legacy Widgets, false otherwise", via: :legacy?
        field :updated_at, :datetime, "the time of this Widget's last update"
        field :created_at, :datetime, "the time at which this Widget was created"
      end

      # Associations can be included by providing include=association_name in the URL.
      # IDs for belongs_to associations will be returned for free if they're native
      # columns on the model, otherwise the user must explicitly request associations
      # to avoid unnecessary loads.
      associations do
        association :features, Feature, "features associated with this Widget"
        association :location, Location, "the location of this Widget"
      end
    end
  end
end
```

### Setup your Controller

Once you've created a presenter like the one above, pass requests through from your Controller.

```ruby
class Api::WidgetsController < ActionController::Base
  include Brainstem::ControllerMethods

  def index
    render json: brainstem_present("widgets") { Widgets.visible_to(current_user) }
  end

  def show
    widget = Widget.find(params[:id])
    render json: brainstem_present_object(widget)
  end
end
```

### Setup Rails to load Brainstem

To configure Brainstem for development and production, we do the following:

1) We add `lib` to our Rails autoload_paths in application.rb with `config.autoload_paths += "#{config.root}/lib"`

2) We setup an initializer in `config/initializers/brainstem.rb`, similar to the following:

```ruby
# In order to support live code reload in the development environment, we register a `to_prepare` callback.  This
# runs once in production (before the first request) and whenever a file has changed in development.
Rails.application.config.to_prepare do
  # Forget all Brainstem configuration.
  Brainstem.reset!

  # Set the current default API namespace.
  Brainstem.default_namespace = :v1

  # (Optional) Load a default base helper into all presenters. You could use this to bring in a concept like `current_user`.
  # While not necessarily the best approach, something like http://stackoverflow.com/a/11670283 can currently be used to
  # access the requesting user inside of a Brainstem presenter. We hope to clean this up by allowing a user to be passed in
  # when presenting in the future.
  module ApiHelper
    def current_user
      Thread.current[:current_user]
    end
  end
  Brainstem::Presenter.helper(ApiHelper)

  # Load the presenters themselves.
  Dir[Rails.root.join("lib/api/v1/*_presenter.rb").to_s].each { |presenter_path| require_dependency(presenter_path) }
end
```

### Make an API request

The scope passed to `brainstem_present` can contain any starting scope conditions that you'd like. Requests can have
includes, filters, and sort orders specified in the params and automatically parsed by Brainstem.

    GET /api/widgets.json?include=features&order=created_at:desc&location_name=san+francisco

Responses will look like the following:

```js
{
  # Total number of results that matched the query.
  count: 5,

  # A lookup table to top-level keys. Necessary
  # because some objects can have associations of
  # the same type as themselves. Also helps to
  # support polymorphic requests.
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
```

#### Valid URL params

Brainstem parses the request params and supports the following:

* Use `order` to select a `sort_order`. Seperate the `sort_order` name and direction with a colon, like `"order=created_at:desc"`.
* Perform a search with `search`. See the `search` block definition in the Presenter DSL section at the bottom of this README.
* To request associations, use the `include` option with a comma-seperated list of association names, for example `"include=features,location"`.
* Pagination is supported by providing either the `page` and `per_page` or `limit` and `offset` URL params. You can set
  legal ranges for these by passing in the `:per_page` and `:max_per_page` options when presenting. The default
  `per_page` is 20 and the default `:max_per_page` is 200.
* Brainstem supports a concept called "only queries" which allow you to request a specific set of records by ID, kind of like
  a batch show request. These queries are triggered by the presence of the URL param `"only"` with a comma-seperated set
  of one or more IDs, for example `"only=1,5,7"`.
* Filters are standard URL parameters. To pass an option to a filter named `:location_name`, provide a request param like
  `location_name=san+francisco`. Because filters are top-level params, avoid naming them after any of the other Brainstem
  keywords, such as `search`, `page`, `per_page`, `limit`, `offset`, `order`, `only`, or `include`.

--

For more detailed examples, please see the rest of this README and our detailed
[Rails example application](https://github.com/mavenlink/brainstem-demo-rails).

## Consuming a Brainstem API

APIs presented with Brainstem are just JSON APIs, so they can be consumed with just about any language. As Brainstem
evolves, we hope that people will contribute client libraries in many languages.

Existing libraries:

* If you're already using Backbone.js, integrating with a Brainstem API is super simple.  Just use the
[brainstem-js](https://github.com/mavenlink/brainstem-js) gem (or its JavaScript contents) to access your relational
Brainstem API from JavaScript.
* For consuming Brainstem APIs in Ruby, take a look at the [brainstem-adaptor](https://github.com/mavenlink/brainstem-adaptor) gem.

### The Brainstem Results Array

    {
      results: [
        { key: "widgets", id: "2" }, { key: "widgets", id: "10" }
      ],

      widgets: {
        "10": {
          id: "10",
          name: "disco ball",
          …

Brainstem returns objects as top-level hashes and provides a `results` array of `key` and `id` objects for finding the
returned data in those hashes. The reason that we use the `results` array is two-fold: 1st) it provides order outside
of the serialized objects so that we can provide objects keyed by ID, and 2nd) it allows for polymorphic responses and
for objects that have associations of their own type (like posts and replies or tasks and sub-tasks).

## Testing your Brainstem API

We recommend writing specs for your Presenters and validating them with the `Brainstem::PresenterValidator`. Here is an
example RSpec shared behavior that you might want to use:

```ruby
shared_examples_for "a Brainstem api presenter" do |presenter_class|
  it 'passes Brainstem::PresenterValidator' do
    validator = Brainstem::PresenterValidator.new(presenter_class)
    validator.valid?
    validator.should be_valid, "expected a valid presenter, got: #{validator.errors.full_messages}"
  end
end
```

And then use it in your presenter specs (e.g., in `spec/lib/api/v1/widget_presenter_spec.rb`:

```ruby
require 'spec_helper'

describe Api::V1::WidgetPresenter do
  it_should_behave_like "a Brainstem api presenter", described_class

  describe 'presented fields' do
    let(:loaded_associations) { { } }
    let(:user_requested_associations) { %w[features location] }
    let(:model) { some_widget } # load from a fixture or create with a factory
    let(:presented_data) {
      # `present_model` will return the representation of a single model. As an optional
      # side effect, it will store any requested associations in the Hash provided
      # to `load_associations_into`.
      described_class.new.present_model(model, user_requested_associations,
                                        load_associations_into: loaded_associations)
    }

    describe 'attributes' do
      it 'presents the attributes' do
        presented_data['name'].should == model.name
      end

      describe 'something conditional on the presenter' do
        describe 'for widgets with this behavior' do
          let(:model) { widget_with_permissions }

          it 'should be true' do
            presented_data['conditional_thing'].should be_truthy
          end
        end

        describe 'for widgets without this behavior' do
          let(:model) { widget_without_permissions }

          it 'should be missing' do
            presented_data.should_not have_key('conditional_thing')
          end
        end
      end
    end

    describe 'associations' do
      it 'should load the associations' do
        presented_data
        loaded_associations.keys.should == %w[features location]
      end
    end
  end
end
```

You can also write a spec that validates all presenters simultaniously by calling `Brainstem.presenter_collection.validate!`.

---

Brainstem also includes some spec helpers for controller specs. In order to use them, you need to include Brainstem in
your controller specs by adding the following to `spec/support/brainstem.rb` or in your `spec/spec_helper.rb`:

```ruby
require 'brainstem/test_helpers'

RSpec.configure do |config|
  config.include Brainstem::TestHelpers, type: :controller
end
```

Now you are ready to use the `brainstem_data` method.

```ruby
# Access the request results:
expect(brainstem_data.results.first.name).to eq('name')

# View the resulting IDs
expect(brainstem_data.results.ids).to eq(['1', '2', '3'])

Selecting an item from a top-level collection by it's id
expect(brainstem_data.users.by_id(235).name).to eq('name')

# Accessing the keys of presented model
expect(brainstem_data.results.first.keys).to =~ %w(id name email address)
```

## Upgrading from the pre-1.0 Brainstem

If you're upgrading from the previous version of Brainstem to 1.0, there are some key changes that you'll want to know about:

* The Presenter DSL has been rebuilt.  Filters and sorts are the same, but the `present` method has been completely replaced
  by a class-level DSL.  Please see the documentation above and below.
* You can use `preload` instead of `custom_preload` now, although `custom_preload` still exists for complex cases.
* `present_objects` and `present` have been renamed to `brainstem_present_objects` and `brainstem_present`.
* `brainstem_key` is now an annotation on presenters and not needed when declaring associations.  It should always be plural.
* `key_map` has been supplanted by `brainstem_key` in the presenter and has been removed.
* `options[:as]` is no longer used with `brainstem_present` / `PresenterCollection#presenting`.  Use the `brainstem_key`
  annotation in your presenters instead.
* `helper` can now take a block or module.

## Advanced Topics

### The presenter DSL

Brainstem provides a rich DSL for building presenters.  This section details the methods available to you.

* `presents` - Accepts a list of classes that this specific presenter knows how to present. These are not inherited.

* `brainstem_key` - The name of the top-level JSON key in which these presented models will be returned. Defaults to the model's
  table name. This annotation is useful when returning data under a different external name than you use for your internal
  models, or when presenting data from STI tables that you want to have use the subclass's name.

* `sort_order` - Give `sort_order` a sort name (as a symbol) and either a string of SQL to be used for ordering
  (like `"widgets.updated_at"`) or a lambda that accepts a scope and an order, like the following:

  ```ruby
  sort_order :composite do |scope, direction|
    # Be careful to avoid a SQL injection!
    sanitized_direction = direction == "desc" ? "desc" : "asc"
    scope.reorder("widgets.created_at #{sanitized_direction}, widgets.id #{sanitized_direction}")
  end
  ```

* `default_sort_order` - The name and direction of the default sort for this presenter. The format is the same as is expected
  in the URL parameter, for example `"name:desc"` or `"name:asc"`. The default value is `"updated_at:desc"`.

* `helper` - Provide a Module or block of helper methods to make available in filter, sort, conditional, association,
  and field lambdas.  Any instance variables defined in the helpers will only be available for a single model presentation.

  ```ruby
  # Provide a global helper Module for all presenters.
  Brainstem::Presenter.helper(ApiHelper)

  # Inside of a Presenter, provide local helpers.
  helper do
    def some_widget_helper(widget)
      widget.some_widget_method
    end
  end
  ```

* `filter` - Declare an available filter for this Presenter. Filters have a name, some options, and a block to run when
  they're requested by a user. When a user provides either `"true"` or `"false"`, as in `include_legacy_widgets=true`,
  they will be coerced into booleans. All other input formats are left as strings. Here are some examples:

  ```ruby
  # Optional filter that applies a lambda.
  filter :location_name do |scope, location_name|
    scope.joins(:locations).where("locations.name = ?", location_name)
  end

  # Filter with an overridable default. This will run on every request,
  # passing in `bool` as `false` unless a user has specified otherwise.
  filter :include_legacy_widgets, default: false do |scope, bool|
    bool ? scope : scope.without_legacy_widgets
  end
  ```

* `search` - This annotation allows you to create a block that is run when your users provide the special `search` URL param.
  When in "search" mode, Brainstem delegates entirely to this block and applies no filters or sorts beyond scoping to the
  base scope passed into `presenting`. You're in charge of implementing whatever filters and sorts you'd like to support
  in search mode inside of your search subsystem. The block should return an array where the first element is an array
  of a page of matching model ids, and the second option is the total number of matched records.

  ```ruby
  search do |search_string, options|
    # options will contain:
    #   include: an array of the requested association inclusions
    #   order: { sort_order: sort_name, direction: direction }
    #   limit and offset or page and per_page, depending on which the user has provided
    #   requested filters and any default filters

    # Talk to your search system (solr, elasticsearch, etc.) here.
    results = do_an_actual_search(search_string, location_name: options[:location_name])

    if results
      [results.map { |result| result.id.to_i }, results.total]
    else
      [false, 0]
    end
  end
  ```

* `preload` - Use this annotation to provide a list of valid associations to preload on this model. If you
  always end up asking a question of each instance that requires loading an association, `preload` it here to avoid an
  N+1 query. The syntax is the same as `preload` or `include` in Rails and allows for nesting.

  ```ruby
  preload :location
  preload :location, features: :feature_creator
  ```

* `fields` - The Brainstem `fields` DSL is how you tell Brainstem what JSON fields to provide in each of your presented models.
  Fields have a name, which is what they will be called in the returned JSON, a type which is used for API documentation,
  an optional documentation string, and a number of options. By default, fields will call a model method with the same
  name as the field's name and return the result. Use the `:via` option to call a different method, or the `:dynamic` option
  to provide a lambda that takes the model and returns the field's output value. Fields can be conditionally returned with the
  `:if` option, detailed in the `conditionals` section below.  Here are some example fields:

  ```ruby
  fields do
    field :name, :string, "the Widget's name"
    field :legacy, :boolean, "true for legacy Widgets, false otherwise",
          via: :legacy?
    field :dynamic_name, :string, "a formatted name for this Widget",
          dynamic: lambda { |widget| "This Widget's name is #{widget.name}" }

    # Fields can be nested
    fields :permissions do
      field :access_level, :integer
    end
  end
  ```

* `associations` - Associations are one of the best features of Brainstem. Your users can provide the names of associations
  to `include` with their response, preventing N+1 API requests.  Declared `association` entries have a name, an ActiveRecord
  class, an optional documentation string, and some options. By default, associations will call the association or
  method on the model with their name. Like fields, you can use `:via` to call a different method or association and
  `:dynamic` to provide a lambda that takes the model and returns a model, array of models, or relation of models.

  If you have an association that tends to be large and expensive to return, you can annotate it with the
  `restrict_to_only: true` option and it will only be returned when the `only` URL param is provided and contains a
  specific set of requested model IDs.

  Included associations will be present in the returned JSON as either `<field>_id`, `<field>_ids`, `<field>_ref`, or `<field>_refs`
  depending on whether they reference a single model, an array (or Relation) of models, a single polymorphic
  association (a polymorphic `belongs_to` or `has_one`), or a plural polymorphic association (a polymorphic `has_many`) respectively.
  When a `*_ref` is returned, it will look like `{ "id": "2", "key": "widgets" }`, telling the consumer the top-level key in
  which to find the identified record by ID.

  If your model has a native column named `<field>_id`, it will be returned for free without being requested. Otherwise,
  users need to request associations via the `include` url param.

  ```ruby
  associations do
    association :features, Feature, "features associated with this Widget"
    association :location, Location, "the location of this Widget"
    association :previous_location, Location, "the Widget's previous location",
                dynamic: lambda { |widget| widget.previous_locations.first }
    association :associated_objects, :polymorphic, "a mixture of objects related to this Widget"
  end
  ```

* `conditionals` - Conditionals are named questions that can be used to restrict which `fields` are returned. The
  `conditionals` block has two available methods, `request` and `model`.  The `request` conditionals run once for the entire
  set of presented models, while `model` ones run once per model. Use `request` conditionals to check and then cache things
  like permissions checks that do not change between models, and use `model` conditionals to ask questions of specific
  models. The optional documentation string is used in API doc generation.

  ```ruby
  conditionals do
    model   :title_is_hello,
            lambda { |model| model.title == 'hello' },
            'visible when the title is hello'

    request :user_is_bob,
            lambda { current_user == 'bob' }, # Assuming some sort of `helper` that provides `current_user`
            'visible only to bob'
  end

  fields do
    field :hello_title, :string, 'the title, when it is exactly the word "hello"',
          dynamic: lambda { |model| model.title + " is the title" },
          if: :title_is_hello

    field :secret, :string, "a secret, via the secret_info model method, only visible to bob and when the model's title is hello",
          via: :secret_info,
          if: [:user_is_bob, :title_is_hello]

    with_options if: :user_is_bob do
      field :bob_title, :string, 'another name for the title, only visible to Bob',
            via: :title
    end
  end
  ```

### A note on Rails 4 Style Scopes

In Rails 3 it was acceptable to write scopes like this: `scope :popular, where(:popular => true)`. This was deprecated
in Rails 4 in preference of scopes that include a callable object: `scope :popular, lambda { where(:popular) => true }`.

If your scope does not take any parameters, this can cause a problem with Brainstem if you use a filter that delegates
to that scope in your presenter. (e.g., `filter :popular`). The preferable way to handle this is to write a Brainstem
scope that delegates to your model scope:

```ruby
filter :popular { |scope| scope.popular }
```

## Contributing

1. Fork Brainstem or Brainstem.js
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request (`git pull-request`)

## License

Brainstem and Brainstem.js were created by Mavenlink, Inc. and are available under the MIT License.
