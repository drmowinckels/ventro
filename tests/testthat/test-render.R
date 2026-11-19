describe("cli_help_rd()", {
  it("renders a notice for a missing command", {
    rd <- cli_help_rd("definitely-not-a-command", "--help")
    expect_match(rd, "was not available")
    expect_no_error(parse_rd_fragment(rd))
  })

  it("renders a notice instead of erroring when the locator fails", {
    rd <- cli_help_rd("x", locate = function(command) stop("boom"))
    expect_match(rd, "was not available")
    expect_no_match(rd, "boom")
  })

  it("renders a notice when the locator returns NULL", {
    rd <- cli_help_rd("x", locate = function(command) NULL)
    expect_match(rd, "not available")
  })

  it("renders a notice when the tool prints nothing", {
    rd <- cli_help_rd(rscript, c("-e", "invisible()"))
    expect_match(rd, "not available")
  })

  it("adds the failure reason when ventro.debug is set", {
    withr::local_options(ventro.debug = TRUE)
    rd <- cli_help_rd("x", locate = function(command) stop("boom {50%}"))
    expect_match(rd, "Reason: boom \\{50\\%\\}", fixed = TRUE)
    expect_no_error(parse_rd_fragment(rd))
    expect_match(cli_help_rd("not-a-command"), "could not be found")
  })

  it("reports a timeout when the tool hangs without printing", {
    skip_if(!nzchar(Sys.which("sleep")), "sleep is not available")
    withr::local_options(ventro.debug = TRUE)
    expect_match(cli_help_rd("sleep", "10", timeout = 1), "timed out")
  })

  it("captures help output that parses as Rd", {
    rd <- cli_help_rd(rscript, "--help")
    expect_match(rd, "^\\\\preformatted")
    expect_no_error(parse_rd_fragment(rd))
  })

  it("passes arguments literally, without shell expansion", {
    rd <- cli_help_rd(
      rscript,
      c("-e", "cat(commandArgs(TRUE))", "--args", "a;", "echo", "$HOME")
    )
    expect_match(rd, "a; echo $HOME", fixed = TRUE)
  })

  it("marks output that was cut off by the timeout", {
    rd <- cli_help_rd(
      rscript,
      c("-e", "cat('partial\\n'); flush(stdout()); Sys.sleep(10)"),
      timeout = 2
    )
    expect_match(rd, "partial")
    expect_match(rd, "[output cut off after 2 seconds]", fixed = TRUE)
  })

  it("lets the locator supply path and environment", {
    locate <- function(command) {
      list(path = rscript, env = c(CLIHELP_TEST = "found it"))
    }
    rd <- cli_help_rd(
      "anything",
      c("-e", "cat(Sys.getenv('CLIHELP_TEST'))"),
      locate = locate
    )
    expect_match(rd, "found it")
  })

  it("renders inside a help page via \\Sexpr", {
    page <- render_rd_text(rd_page(
      "\\section{Help}{",
      sprintf(
        "\\Sexpr[stage=render,results=rd]{ventro::cli_help_rd(%s, \"--help\")}",
        deparse(rscript)
      ),
      "}"
    ))
    expect_match(page, "Usage: Rscript")
  })
})

describe("resolve_function()", {
  it("accepts pkg::fun strings", {
    expect_identical(resolve_function("base::identity"), identity)
  })

  it("accepts bare function names", {
    expect_identical(resolve_function("identity"), identity)
  })
})

describe("rd_escape()", {
  it("escapes Rd special characters", {
    expect_equal(rd_escape("a{b}%c\\d"), "a\\{b\\}\\%c\\\\d")
  })
})

describe("clean_output()", {
  it("removes ANSI codes and overstrikes", {
    expect_equal(clean_output(c("\033[1mbold\033[0m", "_\bu")), "bold\nu")
  })
})
