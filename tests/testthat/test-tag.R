describe("@clihelp", {
  skip_if_not_installed("roxygen2", "7.2.0")

  it("uses a default title that includes the command", {
    rd <- rd_text(clihelp_block("@clihelp mytool --help"))
    expect_match(
      rd,
      "\\section{Command line help: \\code{mytool --help}}",
      fixed = TRUE
    )
    expect_match(rd, 'cli_help_rd("mytool", "--help")', fixed = TRUE)
  })

  it("takes a custom title from extra lines, as plain text", {
    rd <- rd_text(clihelp_block(
      "@clihelp mytool --help",
      "  100% of the options"
    ))
    expect_match(rd, "\\section{100\\% of the options}", fixed = TRUE)
    expect_match(render_rd_text(rd), "100% of the options", fixed = TRUE)
  })

  it("writes Rd that renders when arguments contain %", {
    rd <- rd_text(clihelp_block("@clihelp definitely-not-a-command +%Y"))
    page <- expect_no_warning(render_rd_text(rd))
    expect_match(page, "definitely-not-a-command +%Y", fixed = TRUE)
    expect_match(page, "was not available")
  })

  it("gives one section per tag", {
    rd <- rd_text(clihelp_block("@clihelp tool_a --help", "@clihelp tool_b -h"))
    expect_match(rd, "tool_a")
    expect_match(rd, "tool_b")
  })

  it("warns when no command is given", {
    expect_condition(rd_text(clihelp_block("@clihelp")), "requires a command")
  })

  it("imports cli_help_rd into NAMESPACE", {
    ns <- roc_text(
      clihelp_block("@clihelp mytool --help"),
      roclet = roxygen2::namespace_roclet()
    )
    expect_contains(ns, "importFrom(ventro,cli_help_rd)")
  })

  it("reads the title and locator from DESCRIPTION", {
    pkg_dir <- local_package_dir(c(
      "Config/ventro/title: Options for \\code{{command}}",
      "Config/ventro/locate: demo::find_tool"
    ))
    rd <- rd_text(clihelp_block("@clihelp mytool --help"), wd = pkg_dir)
    expect_match(
      rd,
      "\\section{Options for \\code{mytool --help}}",
      fixed = TRUE
    )
    expect_match(rd, 'locate = "demo::find_tool"', fixed = TRUE)
  })
})

describe("clihelp_call()", {
  it("falls back to an escaped notice when ventro is not installed", {
    help_call <- clihelp_call(list(
      command = "/opt/my tool{1}",
      args = character()
    ))
    fallback <- help_call[[4]]
    expect_match(fallback, "\\code{/opt/my tool\\{1\\}}", fixed = TRUE)
    expect_no_error(parse_rd_fragment(fallback))
  })
})

describe("read_clihelp_config()", {
  it("falls back to defaults without a DESCRIPTION", {
    config <- read_clihelp_config(withr::local_tempdir())
    expect_identical(config$title, default_title)
    expect_null(config$locate)
  })
})
