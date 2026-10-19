# The tests, with Quarto there, so that the ones that render run too. Each
# failure becomes an annotation.
source(".github/annotate.R")
res <- testthat::test_local(stop_on_failure = FALSE, reporter = "progress")
bad <- 0L
for (t in res) {
  for (e in t$results) {
    if (inherits(e, c("expectation_failure", "expectation_error"))) {
      bad <- bad + 1L
      annotate(paste(t$file, t$test), conditionMessage(e))
    }
  }
}
if (bad) stop(bad, " test(s) failed.", call. = FALSE)
