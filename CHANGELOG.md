# Changelog

+ **1.1.0 - _12/18/2017_
  - Add `page_number` key to API responses
  - Add `page_count` key to API responses

+ **1.0.0 - _07/20/2017_
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
