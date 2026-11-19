# The `@clihelp` roxygen tag

Optional shorthand for
[`cli_help_rd()`](https://drmowinckels.github.io/ventro/reference/cli_help_rd.md).
Adds a section to the Rd file that runs a command line tool when the
help page is rendered and shows its output, and adds
`importFrom(ventro, cli_help_rd)` to `NAMESPACE`. Enable it with
`Roxygen: list(markdown = TRUE, packages = "ventro")` in `DESCRIPTION`.

## Details

The first line of the tag is the command followed by its arguments,
split on whitespace, so a single argument cannot contain a space. Any
further lines replace the default section title, as plain text:

    #' @clihelp mri_convert --help
    #'   Options for mri_convert

Package-wide defaults can be set in `DESCRIPTION`:

- `Config/ventro/title`: default section title, as Rd markup, so `%`,
  `{`, `}` and `\` must be escaped with a backslash. `{command}` is
  replaced with the command and its arguments.

- `Config/ventro/locate`: a function, written as `pkg::fun`, that finds
  the tool at render time. See
  [`cli_help_rd()`](https://drmowinckels.github.io/ventro/reference/cli_help_rd.md).
