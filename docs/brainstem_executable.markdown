# Brainstem Command-line Utility

## Usage

Usage: `brainstem SUBCOMMAND options`

e.g. `brainstem generate --markdown` or `brainstem generate --open-api-specification=2`

Get help by running `brainstem help generate`, or `brainstem generate --help`.


## Brainstem Developer Overview

![Brainstem Executable Diagram](./executable.png)

1. The `brainstem` executable instantiates and invokes `Brainstem::Cli`.
2. `Brainstem::Cli` holds a map of acceptable subcommands and the objects that
   contain their logic. It also knows how to extract options and invoke
   execution of these objects, so long as they provide the interface specified
   in `Brainstem::CLI::AbstractCommand`.
3. `Brainstem::CLI::AbstractCommand` is an interface whose descendants define
   an entry point into the application logic. They should expose an option
   parser through their `option_parser` method, one which mutates the `options`
   instance method. The parser is evaluated before the instance of the command
   is `call`ed.

#### Specific Commands

- `Brainstem::CLI::GenerateApiDocsCommand` contains the application logic to
  generate the API docs annotated by Brainstem. See the [Api Doc Generator
  documentation](./api_doc_generator.markdown) for more info.

