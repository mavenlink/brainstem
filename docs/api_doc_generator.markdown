# API Doc Generator: Developer's Guide

This documentation explains the intricacies of Brainstem's built-in API
documentation generation capabilities. For brevity, we refer to this
particular application as 'docgen'.

## Execution

`bundle exec brainstem generate [ARGS]`

## Customizing Output

#### Making Small Customizations to the Existing Formatters

It is easy to make small customizations to the formatters simply by subclassing
them, customizing behaviour as you'd like, and then registering over top of an
existing formatter.

For instance, if you wanted to add a horizontal rule after an endpoint's title:

```ruby
# config/initializers/brainstem.rb
require 'brainstem/api_docs/formatters/markdown/endpoint_formatter'

class MyEndpointFormatter < Brainstem::ApiDocs::Formatters::Markdown::EndpointFormatter
  def format_title!
    super
    output << md_hr
  end
end

Brainstem::ApiDocs::FORMATTERS[:endpoint][:markdown] = MyFormatter.method(:call)
```

You can refer to [all the formatters](../lib/brainstem/api_docs/formatters) to
see what is possible.

#### Adding Custom Formats

Do exactly as above, but instead of declaring it as an existing formatter,
declare the formatter as one of your own choosing:

```ruby
Brainstem::ApiDocs::FORMATTERS[:endpoint][:my_format] = MyFormatter.method(:call)
```

Instead of choosing to inherit from an existing format, you can choose also to
inherit from `Brainstem::ApiDocs::Formatters::AbstractFormatter` as well.

Note that formatters at this time make concrete references to their own format,
so if you decide to inherit from existing formatters, you will have to make
sure these references are changed appropriately.

#### Accessing sibling data from formatters

A formatter formats a wrapping object which serves as a viewmodel to an actual
entity in your application, such as an `ActionController::Base` or a
`Brainstem::Presenter`. There are also additional wrapping objects which hold
collections of these singular wrappers.

These wrappers include the following:

- `Brainstem::ApiDocs::Presenter`
- `Brainstem::ApiDocs::Endpoint`
- `Brainstem::ApiDocs::Controller`
- `Brainstem::ApiDocs::PresenterCollection`
- `Brainstem::ApiDocs::EndpointCollection`
- `Brainstem::ApiDocs::Controller`

In some situations, you may want to include documentation for adjacent or or
similar but unrelated wrapper object. Each of these wrapping objects has a
method called `find_by_class`, which can return these adjacent objects.

At the moment, finding the following is supported:

- `Presenter`:
    - find by `target_class`, e.g.
        - `presenter = find_by_class(association.target_class)`
        - `presenter = find_by_class(User)`

The object responsible for the lookup functionality is the
`Brainstem::ApiDocs::Resolver`, which can be reopened if necessary to provide
further lookups.

#### Adding Additional Configurable Options

The `Brainstem::ApiDocs` module serves double-duty as the receptacle for
configuration information, and is used throughout the docgen application in
order to provide alternatives to defaults.

This can be very handy in any of your customizations, and it is relatively easy
to add, so long as your configuration is used after the host application is
booted up (see [Phases](#phases)).  Simply re-open the module in your
initializer, add your desired `config_accessor`, and refer to the constant in
your formatters:

```ruby
# config/initializers/brainstem.rb

module Brainstem
  module ApiDocs
    config_accessor(:my_config_option) { false }
  end
end
```

```ruby
# my_formatter.rb

Brainstem::ApiDocs.my_config_option
```

## Architectural Overview

### Primary Phases

1. ApiDocs namespace and required classes are loaded.
2. Host application is loaded and required information is extracted
   (introspection).
3. Information is repackaged into wrapping objects (atlas creation).
4. Sink interrogates atlas for specific formatted wrappers (serialization) and
   persists serialized data to disk (persistence).


### Detailed Overview

1. `Brainstem::CLI::GenerateApiDocsCommand` instantiates a builder and a sink,
   and hands the output of the builder to the sink, which serializes and stores
   the input somewhere. It also merges the options given to it on the command
   line with the default options defined in `Brainstem::ApiDocs`.
2. `Brainstem::ApiDocs::Builder` is responsible for retrieving information from
   the host application to be exposed to a sink through a
   `Brainstem::ApiDocs::Introspectors::AbstractIntrospector` subclass. It wraps
   this information in more friendly and documentable ways, producing a series
   of collections that can be iterated or reduced from which to produce
   documentation. It exposes this data through its `atlas` method, which is an
   instance of `Brainstem::ApiDocs::Atlas`.
3. `Brainstem::ApiDocs::Introspectors::AbstractIntrospector` defines an
   interface for objects to return data from the host application. Provided
   with Brainstem is an implementation of
   `Brainstem::ApiDocs::Introspectors::RailsIntrospector`, which can be used to
   extract the required information from a Rails 4 application.
4. `Brainstem::ApiDocs::Atlas` is an object which receives the data from an
introspector and transforms it into a series of collections useful for
producing documentation. It does so by wrapping domain entities and providing
intelligent interfaces on these collections by which to mutate them. It wraps:
    - Routes into `Brainstem::ApiDocs::Endpoint` objects, and these into a
      `Brainstem::ApiDocs::EndpointCollection`;
    - Controllers into `Brainstem::ApiDocs::Controller` objects, and these into
      a `Brainstem::ApiDocs::ControllerCollection`;
    - Presenters into `Brainstem::ApiDocs::Presenter` objects, and these into a
      `Brainstem::ApiDocs::PresenterCollection`.

#### Specific to Markdown Generation

![DocGen overview](./docgen.png)

5. Each of these collection and entity objects includes
   `Brainstem::Concerns::Formattable`, which enables them to be formatted by
   passing them `formatted_as(format, options)`. Formatters inherit from
   `Brainstem::ApiDocs::Formatters::AbstractFormatter`, are loaded by
   `Cerebellum::ApiDocs`, and are stored by self-assigned type. Some or all of
   these formatters may be provided for this type, depending on the desired
   behaviour. Brainstem includes an implementation of a `Markdown` formatter,
   stored under the type `:markdown`, and has a
   `Brainstem::ApiDocs::Formatters::Markdown::EndpointCollectionFormatter` as
   well as an `Endpoint-`, `Controller-`, and `PresenterFormatter`. Note that
   there is not a `ControllerCollectionFormatter`, nor a
   `PresenterCollectionFormatter` included: this is because the Sink shares
   partial responsibility for collection formatting, and in the case of the
   `Brainstem::ApiDocs::Sinks::ControllerPresenterMultifileSink`, outputs each
   controller and presenter as its own file, rather than as a concatenated
   collection.
6. This sink, having received an instance of the `Atlas`, is responsible for
   serializing&mdash;primarily invoking formatting&mdash;and then outputting
   the result somewhere, whether to `$stdout`, a file or files on disk, or a
   remote location.

### Specific to Open Api Specification generation

![OAS 2.0 Docgen overview](./oas_2_docgen.png)

5. Each of these collection and entity objects includes
   `Brainstem::Concerns::Formattable`, which enables them to be formatted by
   passing them `formatted_as(format, options)`. Formatters inherit from
   `Brainstem::ApiDocs::Formatters::AbstractFormatter`, are loaded by
   `Cerebellum::ApiDocs`, and are stored by self-assigned type. Some or all of
   these formatters may be provided for this type, depending on the desired
   behaviour.

   Brainstem includes an implementation of an `Open Api Specification` formatter,
   stored under the type `:oas_v2`. The formatters are listed below:
   - `Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::PresenterFormatter`
   - `Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::ControllerFormatter`
   - `Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::EndpointCollectionFormatter`
   - `Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::EndpointFormatter`

   The EndpointFormatter uses the following formatters:
   - Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::Endpoint::ParamDefinitionsFormatter
   - Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::Endpoint::ResponseDefinitionsFormatter

   The Open Api Specification Sink also uses some formatters to add metadata to the specification. They
   are listed below:
   - `Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::InfoFormatter`
   - `Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::SecurityDefinitionsFormatter`
   - `Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::TagsFormatter`

   Note that there is not a `ControllerCollectionFormatter`, nor a
   `PresenterCollectionFormatter` included: this is because the Sink shares
   partial responsibility for collection formatting, and in the case of the
   `Brainstem::ApiDocs::Sinks::OpenApiSpecificationSink`, outputs all
   controllers and presenters into a single `specification.yml` file.
6. This sink, having received an instance of the `Atlas`, is responsible for
   serializing&mdash;primarily invoking formatting&mdash;and then outputting
   the result somewhere, whether to `$stdout`, a file or files on disk, or a
   remote location.
