# API Doc Generator

Usage:

`brainstem generate OPTIONS`

## Developer Overview

![DocGen overview](./docgen.png)


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
   extract the required information from a Rail 4 application.
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
