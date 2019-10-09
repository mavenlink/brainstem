# Changelog

+ **2.3.0** - _10/09/2019_
  ### Version Support
    - Add official Rails 6.0 compatibility
    - Drop support for Rails 4.1 and below

  ### Bugfixes
    - Address deprecation warnings for Rails 6 by wrapping raw sql in `Arel.sql`

+ **2.2.0** - _08/15/2019_
  ### Bugfixes
    - Add support for API documentation generation in Rails 5.x
    - Address deprecation warnings for Rails 6 by wrapping raw sql in `Arel.sql`

+ **2.1.0** - _05/10/2019_
  ### New Features
    - Add the ability to mark properties as internal for Open API.
    ```ruby
    class ContactsController < ApiController
      internal! "Only used internally"

      brainstem_params do
        actions :index do
          response :hash do
            field :count, :integer,
                  info: "Total count of contacts",
                  internal: "Internal eyes only"
            fields :contacts, :array,
                   item_type: :hash,
                   nodoc: true,
                   info: "Array of contact details" do
              field :full_name, :string,
                    info: "Full name of the contact",
                    internal: true
            end
          end
        end
      end
    end
    ```
    
    - Add `--include-internal` option to CLI:
      `brainstem generate --include-internal --open-api-specification=2` will generate documentation for
      everything that is not marked as `nodoc`.
    
    - Automatically generate documentation for associations
      - `response_key` will be used if given, otherwise, it will use the name of the association appended
        with `_id` or `_ids` for `has_many`.

        Using the example below, the association for `PetCategory` will generate documentation for `shooby_id`,
        while the `Owner` association will generate documentation for `owner_id`.
      - The response will include references to all of the associations, including any `polymorphic_classes` added to
        polymorphic associations.

        In the example below, the documentation for the response will contain references to `PetCategory`, `Vaccine`,
        `Owner`, `Dog`, and `Cat`.

    ```ruby
    class PetsPresenter < Brainstem::Presenter
      presents Pet

      associations do
        association :pet_category, PetCategory,
                    response_key: :shooby_id,
                    type: :belongs_to
        association :vaccines, Vaccine,
                    response_key: :vaccine_ids,
                    type: :has_many
        association :owner, Owner,
                    response_key: :owner_id,
                    type: :has_one
        association :pettable, :polymorphic,
                    response_key: :pettable_ref,
                    polymorphic_classes: [Dog, Cat]
      end
    end
    ```

    - Add support for non-static key fields in responses. When key is non-static, use the new DSL for response params.
      See example below for usage.

       ```ruby
        {
            :attributes => {
                :"#{name}_field" => 'world',
                :"#{name}_ids" => [1, 2, 3],
                :name => name
            },
            :"#{model.class_name}_klass" => {
                :"#{model.class_name}_identifier" => model.identifier,
                :"#{model.association_name}_ids" => [1, 2, 3]
            }
        }
       ```

       A response with non-static key fields written above can be described as follows:

       ```ruby
       class ContactsController < ApiController
         brainstem_params do
           actions :show do
             response :hash do |response_param|
               response_param.fields :attributes, :hash do |attributes|
                 attributes.dynamic_key_field :string
                 attributes.field :some_ids, :array, dynamic: true
                  attributes.field :name, :string, required: true
               end

               response_param.dynamic_key_field :hash do |dk|
                 dk.dynamic_key_field :string
                 dk.field :other_ids, :array, dynamic: true
               end
             end
           end
         end
       end
       ```

    - Add support for non-static key params. When key is non-static, use the new DSL for request params.
      See example below for usage.

      A param with non-static keys like `{ contact.id => 10, :"#{contact.friends_association_name}_ids" => [1, 2, 3] }`
      can be described as follows:

      ```ruby
      class ContactsController < ApiController
        brainstem_params do
          actions :create do
            valid :info, :hash, required: true do |param|
              param.valid_dynamic_param :integer, required: true
              param.valid :some_ids, :array, dynamic: true
            end
          end
        end
      end
      ```

    - Sort orders now default to directions `asc` and `desc`.
      When direction is passed as false, no sort order is generated for the docs.
      - ex.
        ```ruby
          presenter_class.sort_order :created_at, value, info: "sorts by creation time", direction: false
        ```

    - Add new DSL for nested arrays
      ```ruby
        response :array, nested_level: 2, item_type: :hash do
          nested.field :a, :string
          nested.field :b, :integer
        end
      ```
      - An example of the response above: `[[{a: "string", b: 1}, "another string", 4]]`

  ### Bugfixes
    - Nested required fields will now no longer bubble up the required to its parent. A deeply nested field that is 
    required will now only be required on its direct parent.
    - Required fields for a create / update (POST / PUT) request are explicitly called out in the OAS specification
    - Default top-level query params like `only `, `order `, `page`, `per_page`, `include` & `optional` are not
    displayed when the endpoint is not returning brainstem models.

+ **2.0.0** - _05/17/2018_
  - Introduce the capability to document custom response on endpoints
  ```ruby
  class ContactsController < ApiController
    brainstem_params do
      actions :index do
        response :hash do
          field :count, :integer,
                info: "Total count of contacts"

          fields :contacts, :array,
                 item_type: :hash,
                 info: "Array of contact details" do

            field :full_name, :string,
                  info: "Full name of the contact"
          end
        end
      end
    end
  end
  ```
  - Add DSL on controllers to set Open API Specification 2.0 configurations
  ```ruby
  class PetsController < ApiController
    brainstem_params do
      # The `tag` configuration allows grouping of all endpoints
      # in a controller under the same group.
      tag "Adopt a Pet"

      # The `tag_group` configuration introduces another level of nesting
      # and allows grouping multiple controllers under a specific group
      tag_groups "Dogs", "Cats"

      # A list of default MIME types, endpoints on this controller can consume.
      consumes "application/xml", "application/json"

      # A list of default MIME types, endpoints on this controller can produce.
      produces "application/xml"

      # A declaration of which security schemes are applied to endpoints on this controller.
      security []

      # The default transfer protocols for endpoints on this controller.
      schemes "https", "http"

      # Additional external documentation
      external_doc description: 'External Doc',
                   url: 'www.google.com'

      # Declares endpoints on this controller to be deprecated.
      deprecated true

      actions :update do
        # Overriden MIME types the endpoints can consume.
        consumes "application/json"

        # A list of default MIME types the endpoints can produce.
        produces "application/json"

        # Security schemes for this endpoint.
        security { "petstore_auth" => [ "write:pets" ] }

        # Transfer protocols applicable to this endpoint.
        schemes "https"

        # External documentation for the endpoint.
        external_doc description: 'Stock Market News',
                     url: 'www.google.com/finance'

        # Overrides the deprecated value set on the root context.
        deprecated false
      end
    end
  end
  ```
  - Add the capability to generate Open API Specification 2.0

+ **1.4.1** - _05/09/2018_
  - Add the capability to specify an alternate base application / engine the routes are derived from.
    This capability is specific to documemtation generation.

+ **1.3.0** - _04/12/2018_
  - Add the capability to nest fields under evaluable parent blocks where the nested fields are evaluated
    with the resulting value of the parent field.
    ```ruby
        fields :tags, :array,
               info: "The tags for the given category",
               dynamic: -> (widget) { widget.tags } do |tag|

          tag.field :name, :string,
                    info: "Name of the assigned tag"
        end
    ```
  - Add support for nested parameters on an endpoint.
    ```ruby
        model_params :post do |param|
          ...

          param.valid :message, :string, ...

          param.model_params :rating do |rating_param|
            ...

            rating_param.valid :stars, :integer, ...
          end

          params.valid :replies, :array,
                       item_type: :hash, ... do |reply_params|

            reply_params.valid :message, :string,
                               info: "the message of the post"

            ...
          end
        end
    ```
  - Fix issue with nested fields being unable to have the same name as top level fields. 
  - Support generation of markdown documentation for the nested block fields and nested parameters.

+ **1.2.0** - _03/29/2018_
  - Add the capability to indicate an endpoint param is required with the `required` key in the options hash.
  ```ruby
        params.valid :message, :text,
                     required: true,
                     info: "the message of the post"
  ```
  - Add support for specifying the type of an endpoint param. For an endpoint param that has type `Array`,
    type of list items can be specified using `item_type` key in the options hash.
  ```ruby
        params.valid :viewable_by, :array,
                     item_type: :integer,
                     info: "an array of user ids that can access the post"
  ```
  - Add support for specifying the data type of an item for a presenter field using `item_type` key in the
    options hash when the field is of type `Array`.
  ```ruby
        field :aliases, :array,
              item_type: :string,
              info: "an array of user ids that can access the post"
  ```
  - Include the type and item type when generating markdown documentation for endpoint params.
  - Specify the data type of a filter and available values with `items` key in the options hash. If filter is an array,
    data type of items can be specified with the `item_type` property in options.
  ```ruby
        filter :status, :string,
               items: ['Started', 'Completed'],
               info: "only returns elements with the given status"

        filter :sprocket_ids, :array,
               item_type: :integer,
               info: "returns objects associated with given sprocket Ids"
  ```
  - Add support for generating markdown documentation for the following:
    - when the `required` option is specified on an endpoint param
    - when the `type` and `item_type` params are specified on the endpoint param
    - when the `type` and `item_type` params are specified on a presenter field
    - when the `type` and `items` params are specified on a presenter filter

+ **1.1.1** - _01/15/2017_
  - Add `Brainstem.mysql_use_calc_found_rows` boolean config option to utilize MySQL's [FOUND_ROWS()](https://dev.mysql.com/doc/refman/5.7/en/information-functions.html#function_found-rows) functionality to avoid issuing a new query to calculate the record count, which has the potential to up to double the response time of the endpoint.

+ **1.1.0** - _12/18/2017_
  - Add `meta` key to API responses which includes `page_number`, `page_count`, and `page_size` keys.

+ **1.0.0** - _07/20/2017_
  - Add the capability to generate the documentation extracted from your properly annotated
    presenters and controllers using `bundle exec brainstem generate [ARGS]`.
  - Update Brainstem to use Ruby version 2.3.3.
  - Add support for Ruby versions 2.2.7, 2.3.4 & 2.4.1 and drop support for Ruby version 2.1.10.
  - Drop support for specifying description param as a string and not with the `info` key in the options hash.

+ **1.0.0.pre.2** - _04/12/2017_
  - Added support for specifying the description for conditionals, fields and associations with the `info` key in the options hash.
  - Added a deprecation warning when description param is specified as a string and not with the `info` key in the options hash.
  - Fixed: support for conditional, field and association options to be a hash with indifferent access.

+ **1.0.0.pre.1** - _03/07/2017_
  - Implemented new presenter DSL.
  - Added controller helpers for presenting errors.
  - Added support for optional fields.
  - Added support for filtering in conjunction with your search implementation.
  - Added support for defining lookup caches for dynamic fields.
  - Fixed: documentation for default filters.
  - Fixed: ambiguity of `brainstem_key` for presenters that present multiple classes.
  - Fixed: non-deterministic order when sorting records with identical sortable fields (`updated_at`, for instance).

+ **1.0.0.pre** - _10/5/2015_

  + Complete rewrite of the Presenter DSL allowing for introspection and (soon) automatic API documentation.

+ **0.2.5** - _07/22/2014_

  + `Brainstem::Presenter#load_associations!` now:
    + polymorphic 'belongs_to' association is represented as a hash which includes:
      + id: The id of the polymorphic object
      + key: The table name for the class of the polymorphic object

+ **0.2.4** - _01/9/2014_

  + `Brainstem::ControllerMethods#present_object` now simulates an only request (by providing the `only` parameter to Brainstem) when attempting to present a single model.

+ **0.2.3** - _11/21/2013_

  + `Brainstem::ControllerMethods#present_object` now runs the default filters that are defined in the presenter.

  + `Brainstem.presenter_collection` now takes two optional options:
    + `raise_on_empty` - Boolean that defaults to false and when set to true will raise an exception (default: `ActiveRecord::RecordNotFound`) when the result set is empty.
    + `empty_error_class` - Exception class to raise when `raise_on_empty` is true.
