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
