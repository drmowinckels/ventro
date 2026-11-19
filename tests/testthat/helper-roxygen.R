clihelp_block <- function(...) {
  paste(
    c("#' Title", paste("#'", c(...)), "f <- function() {}"),
    collapse = "\n"
  )
}

roc_text <- function(block, wd = NULL, roclet = roxygen2::rd_roclet()) {
  roxygen2::roc_proc_text(roclet, block, wd = wd)
}

rd_text <- function(block, wd = NULL) {
  format(roc_text(block, wd = wd)[[1]])
}

local_package_dir <- function(config_lines, env = parent.frame()) {
  pkg_dir <- withr::local_tempdir(.local_envir = env)
  writeLines(
    c("Package: demo", "Version: 1.0", config_lines),
    file.path(pkg_dir, "DESCRIPTION")
  )
  pkg_dir
}
