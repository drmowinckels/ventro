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
    withr::local_options(ventro.debug = TRUE)
    rd <- cli_help_rd(rscript, c("-e", "invisible()"))
    expect_match(rd, "not available")
    expect_match(rd, "Reason: the tool printed nothing.", fixed = TRUE)
  })

  it("renders a notice when the tool prints only terminal codes", {
    withr::local_options(ventro.debug = TRUE)
    rd <- cli_help_rd(rscript, c("-e", "cat('\\033[0m')"))
    expect_match(rd, "Reason: the tool printed nothing.", fixed = TRUE)
  })

  it("adds the failure reason when ventro.debug is set", {
    withr::local_options(ventro.debug = TRUE)
    rd <- cli_help_rd("x", locate = function(command) stop("boom {50%}"))
    expect_match(rd, "Reason: boom \\{50\\%\\}", fixed = TRUE)
    expect_no_error(parse_rd_fragment(rd))
    expect_match(cli_help_rd("not-a-command"), "could not be found")
  })

  it("strips terminal formatting from the failure reason", {
    withr::local_options(ventro.debug = TRUE)
    rd <- cli_help_rd(
      "x",
      locate = function(command) stop("\033[31mboom\033[39m")
    )
    expect_match(rd, "Reason: boom", fixed = TRUE)
    expect_no_match(rd, "\033", fixed = TRUE)
  })

  it("renders a notice when the failure reason is not valid UTF-8", {
    withr::local_options(ventro.debug = TRUE)
    rd <- cli_help_rd("x", locate = function(command) stop("bad \xff byte"))
    expect_match(rd, "Reason: bad ? byte", fixed = TRUE)
  })

  it("reports a timeout when the tool hangs without printing", {
    skip_if(!nzchar(Sys.which("sleep")), "sleep is not available")
    withr::local_options(ventro.debug = TRUE)
    expect_match(
      cli_help_rd("sleep", "10", timeout = 1),
      "Reason: the tool timed out after 1 seconds.",
      fixed = TRUE
    )
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

describe("strip_terminal_codes()", {
  it("removes ANSI codes and overstrikes", {
    expect_equal(
      strip_terminal_codes(c("\033[1mbold\033[0m", "_\bu")),
      c("bold", "u")
    )
  })

  it("removes terminal hyperlinks and cursor codes", {
    lines <- c(
      "\033]8;;https://example.org\aDocs\033]8;;\a",
      "\033]8;;https://example.org\033\\Site\033]8;;\033\\",
      "\033[?25lspinner\033[?25h"
    )
    expect_equal(strip_terminal_codes(lines), c("Docs", "Site", "spinner"))
  })

  it("removes other escape sequences and control characters", {
    lines <- c(
      "\033]0;window title\aTitle",
      "\033]52;c;ZWNobyBoaQ==\aClipboard",
      "\033P1$r\033\\Device",
      "\033(B\033[mCharset",
      "\u009b31mControl",
      "Bell\a and\r return",
      "Keeps\ttabs"
    )
    expect_equal(
      strip_terminal_codes(lines),
      c(
        "Title",
        "Clipboard",
        "Device",
        "Charset",
        "Control",
        "Bell and return",
        "Keeps\ttabs"
      )
    )
  })

  it("removes escapes outside the common forms", {
    st <- intToUtf8(0x9c)
    lines <- c(
      "\033=keypad",
      "\033#8dec",
      "\033]0;unterminated title",
      paste0("\033]8;;https://example.org", st, "link\033]8;;", st, " tail")
    )
    expect_equal(
      strip_terminal_codes(lines),
      c("keypad", "dec", "", "link tail")
    )
  })

  it("removes overstrikes on multibyte characters", {
    expect_equal(strip_terminal_codes("\u00e9\b\u00e9t\u00e9"), "\u00e9t\u00e9")
  })
})
