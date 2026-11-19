# Command line help as Rd

Runs a command line tool and returns its output as Rd markup, for use
inside `\Sexpr[stage=render,results=rd]` so it runs when a help page is
viewed, not when the package is built. It never throws: if the tool
cannot be found or fails, a short notice is returned instead.

## Usage

``` r
cli_help_rd(command, args = character(), locate = NULL, timeout = 5)
```

## Arguments

- command:

  Name or path of the executable.

- args:

  Character vector of arguments.

- locate:

  Optional locator function, or its name as `"pkg::fun"`.

- timeout:

  Seconds before giving up on the command.

## Value

A single string of Rd markup.

## Usage in roxygen2

With roxygen2 8.0.0 or later and markdown enabled, inline `Rd` code
writes the `\Sexpr` for you:

    #' @section Command line help:
    #' `Rd ventro::cli_help_rd("mri_convert", "--help")`

Add `@importFrom ventro cli_help_rd` once in your package so
`R CMD check` sees the import. The
[`@clihelp`](https://drmowinckels.github.io/ventro/reference/clihelp-tag.md)
tag is an optional shorthand that does both.

## Locating tools

Many tools are not on `PATH`, or need environment variables set before
they run. `locate` is a function, or the name of one as `"pkg::fun"`,
that takes the command name and returns either:

- a path to the executable, or

- a list with `path` and, optionally, `env`: a named character vector of
  environment variables to set while the tool runs.

Return `NULL` if the tool cannot be found. A locator can read the
package's own options or environment variables (e.g. `FREESURFER_HOME`)
so help pages use the same configuration as the wrapper functions.

## Debugging

Every failure shows the same notice. Set `options(ventro.debug = TRUE)`
before viewing the help page to add the reason, such as an error from
the locator.

## Examples

``` r
rscript <- file.path(R.home("bin"), "Rscript")
cat(cli_help_rd(rscript, "--help"))
#> \preformatted{Usage: Rscript [options] file [args]
#>    or: Rscript [options] -e expr [-e expr2 ...] [args]
#> A binary front-end to R, for use in scripting applications.
#> 
#> Options:
#>   --help              Print usage and exit
#>   --version           Print version and exit
#>   --verbose           Print information on progress
#>   --default-packages=LIST  Attach these packages on startup;
#>                         a comma-separated LIST of package names, or 'NULL'
#> and options to R (in addition to --no-echo --no-restore), for example:
#>   --save              Do save workspace at the end of the session
#>   --no-environ        Don't read the site and user environment files
#>   --no-site-file      Don't read the site-wide Rprofile
#>   --no-init-file      Don't read the user R profile
#>   --restore           Do restore previously saved objects at startup
#>   --vanilla           Combine --no-save, --no-restore, --no-site-file,
#>                         --no-init-file and --no-environ
#> 
#> Expressions (one or more '-e <expr>') may be used *instead* of 'file'.
#> Any additional 'args' can be accessed from R via 'commandArgs(TRUE)'.
#> See also  ?Rscript  from within R.}

cat(cli_help_rd("a-tool-that-is-not-installed"))
#> \emph{\code{a-tool-that-is-not-installed} was not available when this help page was rendered.}

locate_rscript <- function(command) {
  list(path = rscript, env = c(R_HELP_DEMO = "1"))
}
cat(cli_help_rd("rscript", "--help", locate = locate_rscript))
#> \preformatted{Usage: Rscript [options] file [args]
#>    or: Rscript [options] -e expr [-e expr2 ...] [args]
#> A binary front-end to R, for use in scripting applications.
#> 
#> Options:
#>   --help              Print usage and exit
#>   --version           Print version and exit
#>   --verbose           Print information on progress
#>   --default-packages=LIST  Attach these packages on startup;
#>                         a comma-separated LIST of package names, or 'NULL'
#> and options to R (in addition to --no-echo --no-restore), for example:
#>   --save              Do save workspace at the end of the session
#>   --no-environ        Don't read the site and user environment files
#>   --no-site-file      Don't read the site-wide Rprofile
#>   --no-init-file      Don't read the user R profile
#>   --restore           Do restore previously saved objects at startup
#>   --vanilla           Combine --no-save, --no-restore, --no-site-file,
#>                         --no-init-file and --no-environ
#> 
#> Expressions (one or more '-e <expr>') may be used *instead* of 'file'.
#> Any additional 'args' can be accessed from R via 'commandArgs(TRUE)'.
#> See also  ?Rscript  from within R.}
```
