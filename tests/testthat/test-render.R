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
      cli_help_rd("sleep", "10", timeout = 0.5),
      "Reason: the tool timed out after 0.5 seconds.",
      fixed = TRUE
    )
  })

  it("marks the cut-off when a shell wrapper times out", {
    skip_if(!nzchar(Sys.which("sh")), "sh is not available")
    rd <- cli_help_rd("sh", c("-c", "echo partial; sleep 10"), timeout = 0.5)
    expect_match(
      rd,
      "partial\n[output cut off after 0.5 seconds]",
      fixed = TRUE
    )
  })

  it("stops the tool when it times out", {
    skip_if(!nzchar(Sys.which("sh")), "sh is not available")
    still_running <- withr::local_tempfile()
    cli_help_rd(
      "sh",
      c("-c", paste("echo partial; sleep 1; touch", shQuote(still_running))),
      timeout = 0.3
    )
    Sys.sleep(1.5)
    expect_false(file.exists(still_running))
  })

  it("stops a tool whose output passes the size limit", {
    started <- Sys.time()
    rd <- cli_help_rd(
      rscript,
      c("-e", "repeat cat(strrep('x', 1000), '\\n')"),
      timeout = 60
    )
    expect_match(rd, "[output cut off after 1,000,000 bytes]", fixed = TRUE)
    expect_lt(as.numeric(Sys.time() - started, units = "secs"), 30)
  })

  it("returns when the tool exits, even if it leaves a child running", {
    skip_if(!nzchar(Sys.which("sh")), "sh is not available")
    started <- Sys.time()
    rd <- cli_help_rd("sh", c("-c", "sleep 30 & echo hi"), timeout = 20)
    expect_lt(as.numeric(Sys.time() - started, units = "secs"), 10)
    expect_identical(rd, "\\preformatted{hi}")
  })

  it("waits indefinitely when timeout is Inf", {
    expect_match(cli_help_rd(rscript, "--help", timeout = Inf), "Usage")
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
    withr::local_envvar(CLIHELP_INHERITED = "inherited")
    rd <- cli_help_rd(
      "anything",
      c("-e", "cat(Sys.getenv(c('CLIHELP_TEST', 'CLIHELP_INHERITED')))"),
      locate = locate
    )
    expect_match(rd, "found it inherited", fixed = TRUE)
  })

  it("captures help written to stderr", {
    rd <- cli_help_rd(rscript, c("-e", "message('usage on stderr')"))
    expect_match(rd, "usage on stderr", fixed = TRUE)
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

describe("read_output()", {
  it("splits lines and drops NUL bytes", {
    output_file <- withr::local_tempfile()
    writeBin(c(charToRaw("a\nb"), as.raw(0), charToRaw("c\n")), output_file)
    output <- read_output(output_file)
    expect_identical(output$lines, c("a", "bc"))
    expect_false(output$truncated)
  })

  it("reads at most the output limit and flags the rest", {
    output_file <- withr::local_tempfile()
    writeBin(as.raw(rep(0x78, output_limit_bytes + 10)), output_file)
    output <- read_output(output_file)
    expect_true(output$truncated)
    expect_identical(nchar(output$lines), as.integer(output_limit_bytes))
  })

  it("ignores output written after the given size", {
    output_file <- withr::local_tempfile()
    writeBin(charToRaw("usage\nKilled: 9\n"), output_file)
    expect_identical(read_output(output_file, size = 6)$lines, "usage")
  })

  it("returns no lines for empty output", {
    output_file <- withr::local_tempfile()
    file.create(output_file)
    expect_identical(read_output(output_file)$lines, character())
  })
})

describe("as_utf8()", {
  it("keeps UTF-8 text and replaces bytes that are not valid UTF-8", {
    skip_if(
      isTRUE(l10n_info()[["Latin-1"]]),
      "Latin-1 locales convert the byte"
    )
    utf8_line <- rawToChar(charToRaw(enc2utf8("caf\u00e9 \u2192")))
    latin1_line <- rawToChar(c(charToRaw("latin1:"), as.raw(0xe9)))
    lines <- as_utf8(c(utf8_line, latin1_line))
    expect_equal(lines, c("caf\u00e9 \u2192", "latin1:?"))
    expect_identical(Encoding(lines[[1]]), "UTF-8")
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
