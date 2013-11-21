# Changelog

+ **0.2.3** - _11/21/2013_

  + `Brainstem::ControllerMethods#present_object` now runs the default filters that are defined in the presenter.
  
  + `Brainstem.presenter_collection` now takes two optional options:
    + `raise_on_empty` - Boolean that defaults to false and when set to true will raise an exception (default: `ActiveRecord::RecordNotFound`) when the result set is empty.
    + `empty_error_class` - Exception class to raise when `raise_on_empty` is true.