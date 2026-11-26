# ventro

Show a command line tool’s own help inside R documentation, generated
**when the help page is viewed**. Users see the help for the version
installed on *their* machine.

## What ventro adds beyond roxygen2

roxygen2 runs code when you document the package, on *your* machine.
Pasting a tool’s help, or generating it with inline `` `r ` `` code,
freezes the help of whatever version you had installed.

Rd’s `\Sexpr[stage=render]` runs code each time a help page is viewed,
and roxygen2 8.0.0’s inline `Rd` code can write it for you. But the code
inside it has to get several things right, or it breaks the help page or
`R CMD check`. ventro is that code:

- **Escaping.** `{`, `}`, `%` and `\` in help text are escaped so the Rd
  stays valid.
- **Never erroring.** A missing tool, failing locator or empty output
  renders a short “not available” notice. `R CMD check` and the PDF
  manual on machines without the tool are unaffected. A tool that hangs
  is stopped after 5 seconds, and any output so far is shown as cut off.
- **Literal arguments.** Arguments reach the tool exactly as written,
  with no shell expansion of `$`, `*` or `;`.
- **Clean output.** ANSI colour codes, terminal bold/underline and
  invalid encodings are stripped.
- **Tools not on `PATH`.** A locator function can find the tool and set
  environment variables such as `FREESURFER_HOME`.
- **An optional `@clihelp` tag.** It writes the section and the import
  for you, and works on roxygen2 versions before 8.0.0.

## Usage

With roxygen2 8.0.0 or later and markdown enabled, use inline `Rd` code:

``` r

#' Convert MRI volumes
#'
#' @section Command line help:
#' `Rd ventro::cli_help_rd("mri_convert", "--help")`
#' @importFrom ventro cli_help_rd
#' @export
mri_convert <- function(...) { ... }
```

Add ventro to `Imports`. The `@importFrom` only needs to appear once in
the package; it stops `R CMD check` from noting that ventro is imported
but not used.

## Tools not on PATH

`locate` is a function, or its name as `"pkg::fun"`, that runs at render
time. It takes the command name and returns a path, a
`list(path = , env = )`, or `NULL` if the tool can’t be found:

``` r

find_tool <- function(command) {
  home <- Sys.getenv("FREESURFER_HOME")
  if (!nzchar(home)) return(NULL)
  list(
    path = file.path(home, "bin", command),
    env = c(FREESURFER_HOME = home)
  )
}
```

``` r

#' `Rd ventro::cli_help_rd("mri_convert", "--help", locate = "mypkg::find_tool")`
```

Reuse the logic your wrapper functions use, so help pages and function
calls agree on which installation they see.

## Debugging

Every failure shows the same notice. To see why, set the option and open
the help page again:

``` r

options(ventro.debug = TRUE)
?mri_convert
```

The notice then includes the reason, such as an error from the locator.

## When the help is generated

In the dynamic help that R and RStudio use by default, the tool runs
each time the page is opened. Static HTML help, installed with
`R CMD INSTALL --html`, and the PDF manual are generated once, so they
show the tool as it was on the machine that installed the package or
built the manual.

## The `@clihelp` tag

An optional roxygen2 tag that writes the section and the import for you,
and also works on roxygen2 versions before 8.0.0. Enable it in
`DESCRIPTION`:

    Imports: ventro
    Roxygen: list(markdown = TRUE, packages = "ventro")

``` r

#' @clihelp mri_convert --help
```

This adds a section titled *Command line help: `mri_convert --help`*.
Arguments are split on whitespace, so a single argument can’t contain a
space; use inline `Rd` code for those. Lines after the command replace
the title, as plain text:

``` r

#' @clihelp mri_convert --help
#'   Options for mri_convert
```

Package-wide defaults go in `DESCRIPTION`:

    Config/ventro/title: Options for \code{{command}}
    Config/ventro/locate: mypkg::find_tool

[command](https://bayesiandemography.github.io/command/) is replaced
with the command and its arguments. This title is Rd markup, so escape
`%`, `{`, `}` and `\` with a backslash.
