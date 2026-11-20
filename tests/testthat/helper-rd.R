rscript <- file.path(R.home("bin"), "Rscript")

parse_rd_fragment <- function(rd) {
  tools::parse_Rd(textConnection(rd), fragment = TRUE)
}

render_rd_text <- function(rd_lines, env = parent.frame()) {
  rd_file <- withr::local_tempfile(fileext = ".Rd", .local_envir = env)
  txt_file <- withr::local_tempfile(fileext = ".txt", .local_envir = env)
  writeLines(rd_lines, rd_file)
  tools::Rd2txt(
    rd_file,
    out = txt_file,
    options = list(underline_titles = FALSE)
  )
  paste(readLines(txt_file), collapse = "\n")
}

rd_page <- function(...) {
  c("\\name{f}\\alias{f}\\title{f}\\description{f}", ...)
}

local_child_tempdir <- function(env = parent.frame()) {
  child_tmp <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(
    TMPDIR = child_tmp,
    TMP = child_tmp,
    TEMP = child_tmp,
    .local_envir = env
  )
  child_tmp
}
