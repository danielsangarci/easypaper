# What ships in the template, as installed.
tpl <- function(...) file.path(system.file("template", package = "easypaper"), ...)

# A fresh project in tempdir(), made the way a user makes one.
new_project <- function(...) {
  p <- tempfile("paper")
  suppressMessages(create_paper(p, git = FALSE, ...))
  p
}

# Run code with `p` as the project every internal helper reads, the way an
# exported function sets it for the length of its own call.
in_project <- function(p, code) {
  .enter_project(p)
  force(code)
}

# The functions a check or a render reads, deparsed into one line, so a test
# can ask what a function calls without matching comments.
code_of <- function(fn) {
  gsub("[[:space:]]+", " ", paste(deparse(fn), collapse = " "))
}

# Name the project with set_paper(), as a user does once a session, until the
# calling test ends; then whatever was named before is named again.
name_paper <- function(path, env = parent.frame()) {
  old <- suppressMessages(set_paper(path))
  do.call(base::on.exit, list(bquote(set_paper(.(old))), add = TRUE),
          envir = env)
  invisible(TRUE)
}

# Any pandoc the package can call: RStudio's, one on the PATH, or Quarto's,
# which is all there is outside RStudio.
skip_if_no_pandoc <- function() {
  ok <- tryCatch({ easypaper:::.sp_find_pandoc(); TRUE }, error = function(e) FALSE)
  skip_if_not(ok, "pandoc is not available")
}
