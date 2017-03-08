# Changelog

+ **1.0.0.pre.1** - _03/07/2017_
  - Implemented new presenter DSL.
  - Added controller helpers for presenting errors.
  - Added support for optional fields.
  - Support filtering in conjunction with your search implementation.
  - Add support for defining lookup caches for dynamic fields.
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
