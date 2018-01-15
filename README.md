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
        field :name, :string, info: "the Widget's name"
        field :legacy, :boolean, info: "true for legacy Widgets, false otherwise", via: :legacy?
        field :longform_description, :string, info: "feature-length description of this Widget", optional: true
        field :updated_at, :datetime, info: "the time of this Widget's last update"
        field :created_at, :datetime, info: "the time at which this Widget was created"
      end

      # Associations can be included by providing include=association_name in the URL.
      # IDs for belongs_to associations will be returned for free if they're native
      # columns on the model, otherwise the user must explicitly request associations
      # to avoid unnecessary loads.
      associations do
        association :features, Feature, info: "features associated with this Widget"
        association :location, Location, info: "the location of this Widget"
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

  def create
    # Note: you are in charge of sanitizing params[brainstem_model_name], likely with strong parameters.
    widget = Widget.new(params[brainstem_model_name])
    if widget.save
      render json: brainstem_present_object(widget)
    else
      render json: brainstem_model_error(widget), status: :unprocessable_entity
    end
  end
end
```

The `Brainstem::ControllerMethods` concern provides:
* `brainstem_model_name` which is inferred from your controller name or settable with `self.brainstem_model_name = :thing`.
* `brainstem_present` and `brainstem_present_object` for presenting a scope of models or a single model.
* `brainstem_model_error` and `brainstem_system_error` for presenting model and system error messages.
* Various methods for auto-documentation of your API.

### Controller Best Practices

We recommend that your base API controller look something like the following.

```ruby
module Api
  module V1
    class ApiController < ApplicationController
      include Brainstem::ControllerMethods

      before_filter :api_authenticate

      rescue_from StandardError, with: :server_error
      rescue_from Brainstem::SearchUnavailableError, with: :search_unavailable
      rescue_from ActiveRecord::RecordNotDestroyed, with: :record_not_destroyed
      rescue_from ActiveRecord::RecordNotFound,
                  ActionController::RoutingError, with: :page_not_found

      private

      def api_authenticate
        # Implement your authentication here.  We recommend Doorkeeper.
      end

      def server_error(exception)
        render json: brainstem_system_error("A server error has occurred."), status: 500
      end

      def search_unavailable
        render json: brainstem_system_error('Search is currently unavailable'), status: 503
      end

      def page_not_found
        render json: brainstem_system_error('Record not found'), status: 404
      end

      def record_not_destroyed
        render json: brainstem_model_error("Could not delete the #{brainstem_model_name.humanize.downcase.singularize}"), status: :unprocessable_entity
      end
    end
  end
end
```

### Setup Rails to Load Brainstem

To configure Brainstem for development and production, we do the following:

1) We add `lib` to our Rails autoload_paths in application.rb with `config.autoload_paths += "#{config.root}/lib"`

2) We setup an initializer in `config/initializers/brainstem.rb`, similar to the following:

```ruby
# In order to support live code reload in the development environment, we
# register a `to_prepare` callback. This # runs once in production (before the
# first request) and whenever a file has changed in development.
Rails.application.config.to_prepare do
  # Forget all Brainstem configuration.
  Brainstem.reset!

  # Set the current default API namespace.
  Brainstem.default_namespace = :v1

  # (Optional) Utilize MySQL's [FOUND_ROWS()](https://dev.mysql.com/doc/refman/5.7/en/information-functions.html#function_found-rows) 
  # functionality to avoid issuing a new query to calculate the record count, 
  # which has the potential to up to double the response time of the endpoint.
  Brainstem.mysql_use_calc_found_rows = true 

  # (Optional) Load a default base helper into all presenters. You could use
  # this to bring in a concept like `current_user`.  # While not necessarily the
  # best approach, something like http://stackoverflow.com/a/11670283 can
  # currently be used to # access the requesting user inside of a Brainstem
  # presenter. We hope to clean this up by allowing a user to be passed in #
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

  # Information about the request and response.
  meta: {
    # Total number of results that matched the query.
    count: 5,

    # Current page returned in the response.
    page_number: 1,

    # Total number pages available.
    page_count: 1,

    # Number of results per page.
    page_size: 20,
  },

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
  of one or more IDs, for example `"only=1,5,7"`. Please note that default filters are still applied to `only` queries, so you will receive
  only the subset of the requested objects that pass any default filters.  To prevent this, you can provide `apply_default_filters=false`
  as a query param.
* Filters are standard URL parameters. To pass an option to a filter named `:location_name`, provide a request param like
  `location_name=san+francisco`. Because filters are top-level params, avoid naming them after any of the other Brainstem
  keywords, such as `search`, `page`, `per_page`, `limit`, `offset`, `order`, `only`, or `include`.
* Brainstem supports optional fields which will only be returned when requested, for example: `optional_fields=field1,field2`

--


## The `brainstem` executable

The `brainstem` executable provided with the gem is at the moment used only to
generate API docs from the command line, but you can verify which commands are
available simply by running:

```sh
bundle exec brainstem
```

This will give you a list of all available commands. Additional help is
available for each command, and can be found by passing the command
the `help` flag, i.e.:

```sh
bundle exec brainstem generate --help
```

--


## API Documentation

### The `generate` command

Running `bundle exec brainstem generate [ARGS]` will generate the documentation
extracted from your properly annotated presenters and controllers.

Note that this does not, at present, *remove* existing docs that may be present
from a previous generation, so it is recommended that you use this executable as
part of a large shell script that empties your directory and regenerates over
top of it if you expect much churn.

### Customizing behavior

While options can be passed on the command line, this can complicate the
invocation, especially when the desired settings are often specific to the
project and do not often change.

As a result, it is possible to specify options through an initializer in your
application that will be used in the absence of command-line flags. Thus,
configuration precedence is in the following order:

1. Command-line flags;
2. Initializer settings;
3. Built-in defaults.

To see a list of the available command-line options, run `bundle exec brainstem
generate --help`.

To see a list of the available initializer settings, view
[lib/brainstem/api_docs.rb](./lib/brainstem/api_docs.rb). You can configure
these in your initializers just by setting them:

```ruby
# config/initializers/brainstem.rb

Brainstem::ApiDocs.tap do |config|
  config.write_path = "/path/to/output"
end
```

### Annotating an API

#### Presenters / Data Models

By and large, Presenters are self-documenting: simply using them as intended
will yield a panoply of data.

##### Docstrings

All common methods that do not explicitly take a description take an `:info`
option, which allows for the specification of an explanatory documentation
string.

As a general rule of thumb, methods that are not used within a block tend to
accept `:info` strings, and those used within a block tend to have their own
`description` argument.

For example:

```ruby
class MyPresenter < Brainstem::Presenter
  sort_order :cost, info: "Sorts by cost" do |scope, direction|
    scope.reorder("myobjects.cost #{direction}")
  end
end
```

The methods that take an `:info` option include:

- `sort_order`
- `filter`
- `association`
- `request/model`
- `field` &mdash; also displays the documentation of any condition set in its
    `:if` option.

The following do not accept documentation:

- `default_sort_order`
- `preload`

##### Nodoc

The following methods accept a `:nodoc` boolean option, which indicates that the
documentation should be suppressed for this particular entry:

- `association` &mdash; hides the association
- `field` &mdash; hides the field
- `sort_order` &mdash; hides the sort order
- `filter` &mdash; hides the filter
- `request` / `model` &mdash; causes the conditional not to be
     listed on any field which specifies it

##### Additional Documentables

In addition to the above, there are three additional methods in the DSL designed
primarily for documentation:

- `nodoc!` &mdash; within a presenter or the `brainstem_params` block within a controller, skips generating the documentation entirely. Useful for hidden or non-public endpoints.
- `title(str, options)` &mdash; used to specify an alternate title for the
    Presenter.
    - `nodoc: true` &mdash; forces fallback to the Presenter's constant
- `description(str, options)` &mdash; used to specify a description for the
    Presenter.
    - `nodoc: true` &mdash; displays no description

##### Example

```ruby
class PostsPresenter < Brainstem::Presenter
  presents Post

  # Hide the entire presenter
  #
  # nodoc!

  # If we temporarily want to disable the custom title, and just display
  # 'Posts', we can add a 'nodoc' option set to true.
  #
  # title "Blog Posts", nodoc: true

  title "Blog Posts"

  description <<-MARKDOWN.strip_heredoc
    The blog post is the primary entity in the blog, which represents a single
    post by one of our authors.
  MARKDOWN

  associations do
    association :author, User, info: "the author of the post"

    # Temporarily disable documenting this relationship as we revamp the
    # editorial system:
    association :editor, User, info: "the editor of the post", nodoc: true
  end
end
```

#### Controllers

The configuration for a controller takes place inside the `brainstem_params` block, e.g.:

```ruby
class PostsController < ApiController
  include Brainstem::Concerns::ControllerDSL

  brainstem_params do   
    title "Posts"
  end
end
```

##### Action Contexts

Configuration that is specified within the root level of the `brainstem_params`
block is applied to the entire controller, and every action within the
controller. This is referred to as the 'default' context, because it is used as
the default for all actions. This lets you specify common defaults for all
actions, as well as a title and description for the controller, which, along
with an annotation of `nodoc!`, are not inherited by the actions.

Each action has its own action context, and the documentation is smart enough
to know that what you want to document for the `index` action is likely not
what you'd like to document for the `show` action, but you are also likely to
have your `create` and `update` methods be very similar.

You can define an action context and place any configuration inside this
context, and it will keep the documentation isolated to that specific action:

```ruby
brainstem_params do
  valid :global_controller_param,
    info: "A trivial example of a param that applies to all actions."

  actions :index do
    # This adds a `blog_id` param to just the `index` action.
    valid :blog_id, info: "The id of the blog to which this post belongs"
  end

  actions :create, :update do
    # This will add an `id` param to both `create` and `update` actions.
    valid :id, info: "The id of the blog post"
  end
end
```

Action contexts, like the default context, are inherited from the parent
controller. So it is often possible to express common setup in the more
abstract controllers, like so:

```ruby
class ApiController
  brainstem_params do
    actions :destroy do
      presents nil
    end
  end
end

class PostsController << ApiController; end
```

In this example, `PostsController` will list no presenter for its `destroy`
method as it inherits this from `ApiController`.

**It is important to specify everything at the most specific level possible.**
Action contexts have a higher priority than defaults, and will fall back to the
action context of the parent controller before they check the default of the
child controller. It's therefore recommended that your documentation be kept
in action contexts as much as possible.

##### `title` / `description` / `nodoc!`

Any of these can be used inside an action context as well.

```ruby
class BlogPostsController < ApiController
  brainstem_params do

    # Make the displayed title of this controller "Posts"
    title "Posts"

    # Fall back to 'BlogPostsController' for a title
    title "Posts", nodoc: true

    # Show description
    description "Access blog posts through these endpoints."

    # Hide description
    description "...", nodoc: true

    # Do not document this controller or any of its endpoints!
    nodoc!

    actions :index do
      # Set the title of this action
      title "Listing blog posts"
      description "..."
    end

    actions :show do
      # Do not display this action.
      nodoc!
    end

  end
end
```


##### `valid` / `model_params`

```ruby
class BlogPostsController < ApiController
  brainstem_params do

    # Add an `:category_id` param to all actions in this controller / children:
    valid :category_id, info: "(required) the category's ID"

    # Do not document this additional field.
    valid :lang,
      info: "(optional) the language of the requested post",
      nodoc: true

    actions :show do
      # Declare a nested param under the `brainstem_model_name` root key,
      # i.e. `params[:blog_post][:id]`):
      model_params do |post|
        post.valid :id, info: "(required) the id of the post"
      end
    end

    actions :share do
      # Declare a nested param with an explicit root key:, i.e. `params[:share][...]`
      model_param :share do
        # ...
      end
    end


    def self.param_root
      :widgets
    end


    actions :update do
      # Declare a dynamic root key, i.e. `params[:widgets][:id]`
      model_params(-> (controller_klass) { controller_class.param_root } do |p|
        p.valid :id #, ...
      end
    end
  end
end
```

##### `presents`

```ruby
class BlogPostsController < ApiController
  brainstem_params do
    # Includes a link to the presenter for `BlogPost` in each action.
    presents BlogPost
  end
```

### Extending and Customizing the API Documentation

For more information on extending and customizing the API documentation, please
see the
[API Doc Generator developer documentation](./docs/api_doc_generator.markdown).


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

  If you wish to perform your Brainstem filters in conjunction with your search block you can use the beta `search_and_filter`
  query strategy. [See this for details](lib/brainstem/query_strategies/README.md).

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
  to provide a lambda that takes the model and returns the field's output value. Fields which result in N + 1 queries can be
  optimized with a `:lookup` option, detailed in the `lookup` section below. Fields can be conditionally returned with the
  `:if` option, detailed in the `conditionals` section below.  Expensive fields can be declared as `optional: true` so that they are
   only returned when `optional_fields=field` is provided in the API request. Here are some example fields:

  ```ruby
  fields do
    field :name, :string, info: "the Widget's name"
    field :legacy, :boolean,
          info: "true for legacy Widgets, false otherwise",
          via: :legacy?
    field :dynamic_name, :string,
          info: "a formatted name for this Widget",
          dynamic: lambda { |widget| "This Widget's name is #{widget.name}" }
    field :longform_description, :string,
          info: "feature-length description of this Widget",
          optional: true

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
  Associations which result in N + 1 queries can be optimized with a `:lookup` option, detailed in the `lookup` secontion below.

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
    association :features, Feature, info: "features associated with this Widget"
    association :location, Location, info: "the location of this Widget"
    association :previous_location, Location,
                info: "the Widget's previous location",
                dynamic: lambda { |widget| widget.previous_locations.first }
    association :associated_objects, :polymorphic,
                info: "a mixture of objects related to this Widget"
  end
  ```

* `lookup` - Use this option to avoid N + 1 queries for Fields and Associations. The `lookup` lambda runs once when
presenting and every presented model gets its assocation or value from the cache the `lookup` lambda generates. The
`lookup` lambda takes in the presented models and should generate a cache containing the models' coresponding assocations
or values. Brainstem expects the return result of the `lookup` to be a Hash where the keys are the presented models' ids
and the values are those models' associations or values. Use the `lookup` when you would like to preload but cannot
e.g. if your association references `current_user`. If both a `lookup` and `dynamic` options are defined,
the `lookup` will be used.

  ```ruby
  associations do
    association :current_user_groups, Group,
      info: "the Groups for the current user",
      lookup: lambda { |models|
        Group.where(subject_id: models.map(&:id)
          .where(user_id: current_user.id)
          .group_by { |group| group.subject_id }
      }
  end
  ```

* `lookup_fetch` - Use this option for Fields and Associations if you would like to override how a model should retrieve
 its value or assocation returned by the `lookup` cache. The `lookup_fetch` lambda takes in the presented model and the result
 from the `lookup` lambda. It should return the association or value from the `lookup` cache for that `model`. If
 `lookup_fetch` is not defined, Brainstem will run the default. The example `lookup_fetch` below is equivalent to the default.

  ```ruby
  fields do
    field :current_user_post_count, Post,
      info: "count of Posts the current_user has for this model",
      lookup: lambda { |models|
        lookup = Post.where(subject_id: models.map(&:id)
          .where(user_id: current_user.id)
          .group_by { |post| post.subject_id }

        lookup
       },
       lookup_fetch: lambda { |lookup, model| lookup[model.id] }
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
            info: 'visible when the title is hello'

    request :user_is_bob,
            lambda { current_user == 'bob' }, # Assuming some sort of `helper` that provides `current_user`
            info: 'visible only to bob'
  end

  fields do
    field :hello_title, :string,
          info: 'the title, when it is exactly the word "hello"',
          dynamic: lambda { |model| model.title + " is the title" },
          if: :title_is_hello

    field :secret, :string,
          info: "a secret, via the secret_info model method, only visible to bob and when the model's title is hello",
          via: :secret_info,
          if: [:user_is_bob, :title_is_hello]

    with_options if: :user_is_bob do
      field :bob_title, :string,
            info: 'another name for the title, only visible to Bob',
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
