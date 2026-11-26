# Showing command line help in R documentation

You’ve written an R function that wraps a command line tool. Its help
page says “see `mri_convert --help` for the full list of options”, and
every user who reads that line has to leave R, open a terminal, and hope
the tool on their `PATH` is the one your function will call.

The obvious fix is to paste the tool’s help into your roxygen block.
That works until the tool’s next release, when your copy quietly goes
stale. The help you want is the help of the tool *the user* has
installed, generated when they open the page.

R can do that. Rd files support `\Sexpr[stage=render]`, a macro that
runs R code each time a help page is displayed. ventro provides the R
code to put inside it.

``` r

library(ventro)
```

## Why not just call the tool?

Here is roughly what you might write first: run the tool, paste its
output into the page. We’ll use a made-up line of help text that looks
like plenty of real ones.

``` r

raw_help <- "Usage: tool [--format=%d] {input} [output]"
```

Put that text straight into a help page, and this is what readers get:

``` r

render_rd("\\preformatted{", raw_help, "}")
#> Command line help:
#> 
#>      Usage: tool [--format=
#> 
```

Everything from `%` onwards is gone, because `%` starts a comment in Rd.
Braces and backslashes cause similar trouble. Real help output is full
of all three, and you only find out when a page renders wrong or not at
all.

There are other ways it goes wrong that are easier to miss. The tool
might print colour codes or terminal bold. It might hang. And on CRAN’s
machines it is almost certainly not installed, so a call that errors
there breaks the PDF manual, and `R CMD check` with it.

## `cli_help_rd()`

[`cli_help_rd()`](https://drmowinckels.github.io/ventro/reference/cli_help_rd.md)
runs the tool and returns its help as Rd markup that is safe to put in a
page. To keep this vignette runnable everywhere, we’ll use `Rscript` as
the tool, since every R installation has one.

``` r

rscript <- file.path(R.home("bin"), "Rscript")
print_raw_help <- c("-e", sprintf("cat(%s)", deparse(raw_help)))
render_rd(cli_help_rd(rscript, print_raw_help))
#> Command line help:
#> 
#>      Usage: tool [--format=%d] {input} [output]
#> 
```

This time the `%` and the braces survive:
[`cli_help_rd()`](https://drmowinckels.github.io/ventro/reference/cli_help_rd.md)
wraps the output in `\preformatted{}`, escapes it, and strips terminal
formatting. When the tool isn’t there, it returns a notice instead of an
error:

``` r

render_rd(cli_help_rd("mri_convert", "--help"))
#> Command line help:
#> 
#>      _'mri_convert' was not available when this help page was
#>      rendered._
```

A tool that hangs is stopped after five seconds (change it with
`timeout`), and whatever it printed by then is shown, marked as cut off.

## Using it in roxygen2

roxygen2 8.0.0 added inline `Rd` code, which writes the `\Sexpr` for
you. With markdown enabled, a wrapper’s documentation looks like this:

``` r

#' Convert MRI volumes
#'
#' @section Command line help:
#' `Rd ventro::cli_help_rd("mri_convert", "--help")`
#' @importFrom ventro cli_help_rd
#' @export
mri_convert <- function(...) {
  ...
}
```

Add ventro to `Imports` in `DESCRIPTION`. The `@importFrom` line only
needs to appear once in your package. Without it, `R CMD check` notes
that ventro is imported but never used, because the only call to it
lives inside the Rd files.

Here is the Rd that roxygen2 writes, rendered the way `?mri_convert`
would show it, with `Rscript` standing in for `mri_convert`:

``` r

render_rd(sprintf(
  "\\Sexpr[stage=render,results=rd]{ventro::cli_help_rd(%s, \"--help\")}",
  deparse(rscript)
))
#> Command line help:
#> 
#>      Usage: Rscript [options] file [args]
#>         or: Rscript [options] -e expr [-e expr2 ...] [args]
#>      A binary front-end to R, for use in scripting applications.
#>      
#>      Options:
#>        --help              Print usage and exit
#>        --version           Print version and exit
#>        --verbose           Print information on progress
#>        --default-packages=LIST  Attach these packages on startup;
#>                              a comma-separated LIST of package names, or 'NULL'
#>      and options to R (in addition to --no-echo --no-restore), for example:
#>        --save              Do save workspace at the end of the session
#>        --no-environ        Don't read the site and user environment files
#>        --no-site-file      Don't read the site-wide Rprofile
#>        --no-init-file      Don't read the user R profile
#>        --restore           Do restore previously saved objects at startup
#>        --vanilla           Combine --no-save, --no-restore, --no-site-file,
#>                              --no-init-file and --no-environ
#>      
#>      Expressions (one or more '-e <expr>') may be used *instead* of 'file'.
#>      Any additional 'args' can be accessed from R via 'commandArgs(TRUE)'.
#>      See also  ?Rscript  from within R.
#> 
```

## Tools that aren’t on `PATH`

Plenty of tools need more than a name to run. FreeSurfer, for example,
lives wherever `FREESURFER_HOME` points, and its programs expect that
variable to be set.

`locate` takes a function that finds the tool. It gets the command name
and returns a path, a list with `path` and `env`, or `NULL` when the
tool can’t be found:

``` r

find_freesurfer_tool <- function(command) {
  home <- Sys.getenv("FREESURFER_HOME")
  if (!nzchar(home)) {
    return(NULL)
  }
  list(
    path = file.path(home, "bin", command),
    env = c(FREESURFER_HOME = home)
  )
}
```

In roxygen, pass it by name, so the call is resolved when the help page
is rendered:

``` r

#' `Rd ventro::cli_help_rd("mri_convert", "--help", locate = "mypkg::find_freesurfer_tool")`
```

The locator should be the same function your wrappers use to find the
tool. That way the help page and the function call can’t disagree about
which installation they mean.

## When something goes wrong

Every failure shows the same notice. That’s deliberate: a reader of the
help page shouldn’t see a stack trace. It’s less helpful when you’re the
one trying to work out why your locator isn’t finding anything. Set
`ventro.debug` and the notice says why:

``` r

options(ventro.debug = TRUE)
broken_locator <- function(command) stop("FREESURFER_HOME points nowhere")
render_rd(cli_help_rd("mri_convert", locate = broken_locator))
#> Command line help:
#> 
#>      _'mri_convert' was not available when this help page was rendered.
#>      Reason: FREESURFER_HOME points nowhere_
options(ventro.debug = NULL)
```

## The `@clihelp` shorthand

If you’d rather not write the inline code, or you’re on roxygen2 older
than 8.0.0, ventro also provides a roxygen tag. Turn it on in
`DESCRIPTION`:

    Imports: ventro
    Roxygen: list(markdown = TRUE, packages = "ventro")

Then one line per tool:

``` r

#' @clihelp mri_convert --help
```

The tag writes the section and the `importFrom()` for you. It also reads
two package-wide settings from `DESCRIPTION`, so you don’t repeat them
in every block:

    Config/ventro/title: Options for \code{{command}}
    Config/ventro/locate: mypkg::find_freesurfer_tool

The tradeoff is that its arguments are split on whitespace, so a single
argument can’t contain a space. For those, use the inline form.

## When the help is generated

In the dynamic help that R and RStudio use by default, the tool runs
each time the page is opened. Static HTML help (`R CMD INSTALL --html`)
and the PDF manual are built once, so they show the tool as it was on
the machine that installed the package or built the manual. On CRAN that
usually means the “not available” notice. For a pkgdown site, it means
the help of whatever is installed where the site is built, which is
worth keeping in mind if you build it on CI.
