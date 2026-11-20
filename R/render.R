#' Command line help as Rd
#'
#' Runs a command line tool and returns its output as Rd markup, for use
#' inside `\Sexpr[stage=render,results=rd]` so it runs when a help page is
#' viewed, not when the package is built. It never throws: if the tool
#' cannot be found or fails, a short notice is returned instead.
#'
#' @section Usage in roxygen2:
#' With roxygen2 8.0.0 or later and markdown enabled, inline `Rd` code
#' writes the `\Sexpr` for you:
#'
#' ```
#' #' @section Command line help:
#' #' `Rd ventro::cli_help_rd("mri_convert", "--help")`
#' ```
#'
#' Add `@importFrom ventro cli_help_rd` once in your package so
#' `R CMD check` sees the import. The [`@clihelp`][clihelp-tag] tag is an
#' optional shorthand that does both.
#'
#' @section Locating tools:
#' Many tools are not on `PATH`, or need environment variables set before
#' they run. `locate` is a function, or the name of one as `"pkg::fun"`,
#' that takes the command name and returns either:
#'
#' * a path to the executable, or
#' * a list with `path` and, optionally, `env`: a named character vector
#'   of environment variables to set while the tool runs.
#'
#' Return `NULL` if the tool cannot be found. A locator can read the
#' package's own options or environment variables (e.g. `FREESURFER_HOME`)
#' so help pages use the same configuration as the wrapper functions.
#'
#' @section Debugging:
#' Every failure shows the same notice. Set `options(ventro.debug = TRUE)`
#' before viewing the help page to add the reason, such as an error from
#' the locator.
#'
#' @param command Name or path of the executable.
#' @param args Character vector of arguments.
#' @param locate Optional locator function, or its name as `"pkg::fun"`.
#' @param timeout Seconds before giving up on the command.
#' @return A single string of Rd markup.
#' @export
#' @examples
#' rscript <- file.path(R.home("bin"), "Rscript")
#' cat(cli_help_rd(rscript, "--help"))
#'
#' cat(cli_help_rd("a-tool-that-is-not-installed"))
#'
#' locate_rscript <- function(command) {
#'   list(path = rscript, env = c(R_HELP_DEMO = "1"))
#' }
#' cat(cli_help_rd("rscript", "--help", locate = locate_rscript))
cli_help_rd <- function(
  command,
  args = character(),
  locate = NULL,
  timeout = 5
) {
  tryCatch(
    render_cli_help(command, args, locate, timeout),
    error = function(e) unavailable_notice(command, conditionMessage(e))
  )
}

render_cli_help <- function(command, args, locate, timeout) {
  tool <- locate_tool(command, locate)
  if (is.null(tool)) {
    stop("the tool could not be found.", call. = FALSE)
  }
  result <- run_cli(tool, args, timeout)
  lines <- strip_terminal_codes(result$lines)
  if (!any(nzchar(lines))) {
    if (result$timed_out) {
      stop(
        sprintf("the tool timed out after %s seconds.", timeout),
        call. = FALSE
      )
    }
    stop("the tool printed nothing.", call. = FALSE)
  }
  help_text <- paste(lines, collapse = "\n")
  if (result$timed_out) {
    help_text <- sprintf(
      "%s\n[output cut off after %s seconds]",
      help_text,
      timeout
    )
  }
  paste0("\\preformatted{", rd_escape(help_text), "}")
}

unavailable_notice <- function(command, reason) {
  notice <- sprintf(
    "\\code{%s} was not available when this help page was rendered.",
    rd_escape(command)
  )
  if (isTRUE(getOption("ventro.debug"))) {
    notice <- paste0(
      notice,
      " Reason: ",
      rd_escape(strip_terminal_codes(reason))
    )
  }
  paste0("\\emph{", notice, "}")
}

locate_tool <- function(command, locate) {
  if (is.null(locate)) {
    return(as_tool(command))
  }
  as_tool(resolve_function(locate)(command))
}

as_tool <- function(found) {
  if (is.null(found)) {
    return(NULL)
  }
  if (is.character(found)) {
    found <- list(path = found)
  }
  path <- Sys.which(found$path)
  if (!nzchar(path)) {
    return(NULL)
  }
  list(path = unname(path), env = found$env)
}

resolve_function <- function(locate) {
  if (is.function(locate)) {
    return(locate)
  }
  parts <- strsplit(locate, ":::?")[[1]]
  if (length(parts) != 2) {
    return(get(locate, mode = "function"))
  }
  get(parts[[2]], envir = asNamespace(parts[[1]]), mode = "function")
}

run_cli <- function(tool, args, timeout) {
  env <- paste0(names(tool$env), "=", shQuote(tool$env), recycle0 = TRUE)
  lines <- suppressWarnings(
    system2(
      tool$path,
      shQuote(args),
      stdout = TRUE,
      stderr = TRUE,
      env = env,
      timeout = timeout
    )
  )
  list(lines = lines, timed_out = identical(attr(lines, "status"), 124L))
}

strip_terminal_codes <- function(x) {
  x <- iconv(x, "", "UTF-8", sub = "?")
  x <- gsub(ecma48_escape, "", x, perl = TRUE)
  gsub(
    ".\b|[\\x{01}-\\x{08}\\x{0b}-\\x{1f}\\x{7f}-\\x{9f}]",
    "",
    x,
    perl = TRUE
  )
}

ecma48_escape <- paste(
  "(?:\033\\[|\\x{9b})[0-?]*[ -/]*[@-~]",
  "\033[]PX^_][^\a\033\\x{9c}]*(?:\a|\033\\\\|\\x{9c})?",
  "\033[ -/]*[0-~]",
  sep = "|"
)

rd_escape <- function(x) {
  x <- rd_escape_rlike(x)
  x <- gsub("{", "\\{", x, fixed = TRUE)
  gsub("}", "\\}", x, fixed = TRUE)
}

rd_escape_rlike <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  gsub("%", "\\%", x, fixed = TRUE)
}
