#' The `@clihelp` roxygen tag
#'
#' Optional shorthand for [cli_help_rd()]. Adds a section to the Rd file
#' that runs a command line tool when the help page is rendered and shows
#' its output, and adds `importFrom(ventro, cli_help_rd)` to `NAMESPACE`.
#' Enable it with `Roxygen: list(markdown = TRUE, packages = "ventro")`
#' in `DESCRIPTION`.
#'
#' The first line of the tag is the command followed by its arguments,
#' split on whitespace, so a single argument cannot contain a space. Any
#' further lines replace the default section title, as plain text:
#'
#' ```
#' #' @clihelp mri_convert --help
#' #'   Options for mri_convert
#' ```
#'
#' Package-wide defaults can be set in `DESCRIPTION`:
#'
#' * `Config/ventro/title`: default section title, as Rd markup, so `%`,
#'   `{`, `}` and `\` must be escaped with a backslash. `{command}` is
#'   replaced with the command and its arguments.
#' * `Config/ventro/locate`: a function, written as `pkg::fun`, that
#'   finds the tool at render time. See [cli_help_rd()].
#'
#' @name clihelp-tag
NULL

#' @exportS3Method roxygen2::roxy_tag_parse
roxy_tag_parse.roxy_tag_clihelp <- function(x) {
  lines <- trimws(strsplit(x$raw, "\n", fixed = TRUE)[[1]])
  lines <- lines[nzchar(lines)]
  if (length(lines) == 0) {
    roxygen2::warn_roxy_tag(
      x,
      c("requires a command", i = "For example: {.code @clihelp mytool --help}")
    )
    return(NULL)
  }
  words <- strsplit(lines[[1]], "\\s+")[[1]]
  title <- if (length(lines) > 1) rd_escape(paste(lines[-1], collapse = " "))
  x$val <- list(command = words[[1]], args = words[-1], title = title)
  x
}

#' @exportS3Method roxygen2::roxy_tag_rd
roxy_tag_rd.roxy_tag_clihelp <- function(x, base_path, env) {
  config <- read_clihelp_config(base_path)
  x$val$title <- x$val$title %||% config$title
  x$val$locate <- config$locate
  roxygen2::rd_section("clihelp", list(x$val))
}

#' @exportS3Method roxygen2::roxy_tag_ns
roxy_tag_ns.roxy_tag_clihelp <- function(x, block, env) {
  "importFrom(ventro,cli_help_rd)"
}

#' @export
format.rd_section_clihelp <- function(x, ...) {
  vapply(x$value, clihelp_section, character(1), USE.NAMES = FALSE)
}

#' @export
merge.rd_section_clihelp <- function(x, y, ...) {
  roxygen2::rd_section("clihelp", c(x$value, y$value))
}

default_title <- "Command line help: \\code{{command}}"

read_clihelp_config <- function(base_path) {
  desc_path <- file.path(base_path, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    return(list(title = default_title, locate = NULL))
  }
  values <- read.dcf(
    desc_path,
    fields = c("Config/ventro/title", "Config/ventro/locate")
  )
  list(
    title = na_to_null(values[[1, "Config/ventro/title"]]) %||% default_title,
    locate = na_to_null(values[[1, "Config/ventro/locate"]])
  )
}

clihelp_section <- function(spec) {
  invocation <- paste(c(spec$command, spec$args), collapse = " ")
  title <- gsub("{command}", rd_escape(invocation), spec$title, fixed = TRUE)
  paste0(
    "\\section{",
    title,
    "}{\n",
    "\\Sexpr[stage=render,results=rd]{",
    rd_escape_rlike(deparse1(clihelp_call(spec))),
    "}\n",
    "}\n"
  )
}

clihelp_call <- function(spec) {
  help_call <- bquote(ventro::cli_help_rd(.(spec$command), .(spec$args)))
  help_call$locate <- spec$locate
  fallback <- sprintf(
    "\\emph{Install the ventro package to see the help for \\code{%s}.}",
    rd_escape(spec$command)
  )
  has_ventro <- quote(requireNamespace("ventro", quietly = TRUE))
  bquote(if (.(has_ventro)) .(help_call) else .(fallback))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

na_to_null <- function(x) if (is.na(x) || !nzchar(x)) NULL else x
