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

# Answer yes when a call asks to write into the project the working directory
# is in, as a user would in an interactive session, until the calling test
# ends; and forget the permissions given, so each test starts with none.
allow_writes <- function(env = parent.frame()) {
  .ep$allowed <- NULL
  local_mocked_bindings(.interactive = function() TRUE,
                        .ask_yes_no = function(q) TRUE, .env = env)
  do.call(base::on.exit, list(quote(.ep$allowed <- NULL), add = TRUE),
          envir = env)
  invisible(TRUE)
}
