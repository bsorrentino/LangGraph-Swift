# USAGE: swift package [<package-manager-option>] generate-documentation [<plugin-options>] [<docc-options>]
# 
# PACKAGE MANAGER OPTIONS:
#   --allow-writing-to-package-directory
#                           Allow the plugin to write to the package directory.
#   --allow-writing-to-directory <directory-path>
#                           Allow the plugin to write to an additional directory.
# 
# PLUGIN OPTIONS:
#   --target <target>       Generate documentation for the specified target.
#   --product <product>     Generate documentation for the specified product.
#   --disable-indexing, --no-indexing
#                           Disable indexing for the produced DocC archive.
#         Produces a DocC archive that is best-suited for hosting online but incompatible with Xcode.
#   --experimental-skip-synthesized-symbols
#                           Exclude synthesized symbols from the generated documentation
#         Experimental feature that produces a DocC archive without compiler synthesized symbols.
#   --include-extended-types / --exclude-extended-types
#                           Control whether extended types from other modules are shown in the produced DocC archive. (default: --include-extended-types)
#         Allows documenting symbols that a target adds to its dependencies.
# 
# DOCC ARGUMENTS:
#   <source-bundle-path>    Path to a documentation bundle directory.
#         The '.docc' bundle docc will build.
# 
# DOCC OPTIONS:
#   --platform <platform>   Set the current release version of a platform.
#         Use the following format: "name={platform name},version={semantic
#         version}".
#   --analyze               Outputs additional analyzer style warnings in
#                           addition to standard warnings/errors.
#   --emit-digest           Writes additional metadata files to the output
#                           directory.
#   --emit-lmdb-index       Writes an LMDB representation of the navigator index
#                           to the output directory.
#         A JSON representation of the navigator index is emitted by default.
#   --ide-console-output, --emit-fixits
#                           Format output to the console intended for an IDE or
#                           other tool to parse.
#   --diagnostics-file, --diagnostics-output-path <diagnostics-file>
#                           The location where the documentation compiler writes
#                           the diagnostics file.
#         Specifying a diagnostic file path implies '--ide-console-output'.
#   --experimental-documentation-coverage
#                           Generates documentation coverage output. (currently
#                           Experimental)
#   --level <level>         Desired level of documentation coverage output.
#                           (default: none)
#   --kinds <kind>          The kinds of entities to filter generated
#                           documentation for.
#   --experimental-enable-custom-templates
#                           Allows for custom templates, like `header.html`.
#   --enable-inherited-docs Inherit documentation for inherited symbols
#   --warnings-as-errors    Treat warnings as errors
#   --checkout-path <checkout-path>
#                           The root path on disk of the repository's checkout.
#   --source-service <source-service>
#                           The source code service used to host the project's
#                           sources.
#         Required when using '--source-service-base-url'. Supported values are
#         'github', 'gitlab', and 'bitbucket'.
#   --source-service-base-url <source-service-base-url>
#                           The base URL where the source service hosts the
#                           project's sources.
#         Required when using '--source-service'. For example,
#         'https://github.com/my-org/my-repo/blob/main'.
#   --allow-arbitrary-catalog-directories
#                           Experimental: allow catalog directories without the
#                           `.docc` extension.
#   --fallback-display-name, --display-name <fallback-display-name>
#                           A fallback display name if no value is provided in
#                           the documentation bundle's Info.plist file.
#   --fallback-bundle-identifier, --bundle-identifier <fallback-bundle-identifier>
#                           A fallback bundle identifier if no value is provided
#                           in the documentation bundle's Info.plist file.
#   --fallback-bundle-version, --bundle-version <fallback-bundle-version>
#                           A fallback bundle version if no value is provided in
#                           the documentation bundle's Info.plist file.
#   --default-code-listing-language <default-code-listing-language>
#                           A fallback default language for code listings if no
#                           value is provided in the documentation bundle's
#                           Info.plist file.
#   --fallback-default-module-kind <fallback-default-module-kind>
#                           A fallback default module kind if no value is
#                           provided in the documentation bundle's Info.plist
#                           file.
#   -o, --output-path, --output-dir <output-path>
#                           The location where the documentation compiler writes
#                           the built documentation.
#   --additional-symbol-graph-dir <additional-symbol-graph-dir>
#                           A path to a directory of additional symbol graph
#                           files.
#   --diagnostic-level <diagnostic-level>
#                           Filters diagnostics above this level from output
#         This filter level is inclusive. If a level of `information` is
#         specified, diagnostics with a severity up to and including
#         `information` will be printed.
#         This option is ignored if `--analyze` is passed.
#         Must be one of "error", "warning", "information", or "hint"
#   --transform-for-static-hosting/--no-transform-for-static-hosting
#                           Produce a DocC archive that supports static hosting
#                           environments. (default:
#                           --transform-for-static-hosting)
#   --hosting-base-path <hosting-base-path>
#                           The base path your documentation website will be
#                           hosted at.
#         For example, to deploy your site to
#         'example.com/my_name/my_project/documentation' instead of
#         'example.com/documentation', pass '/my_name/my_project' as the base
#         path.
#   -h, --help              Show help information.


swift package \
    --allow-writing-to-directory ./docs \
    generate-documentation \
    --target LangGraph \
    --disable-indexing \
    --transform-for-static-hosting \
    --output-path ./docs

