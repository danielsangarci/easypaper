# GitHub shows the logs of a run only to someone signed in, but its
# annotations to anyone: every failure is written as one, so it can be read
# from the API. Sourced by the scripts of render.yaml.
annotate <- function(title, lines) {
  msg <- paste(utils::tail(lines, 60), collapse = "\n")
  msg <- gsub("%", "%25", msg, fixed = TRUE)
  msg <- gsub("\r", "%0D", msg, fixed = TRUE)
  msg <- gsub("\n", "%0A", msg, fixed = TRUE)
  title <- gsub("[,:\n]", " ", title)
  cat("::error title=", title, "::", msg, "\n", sep = "")
}
