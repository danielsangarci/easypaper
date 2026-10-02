# The compendium of a double-blind submission: the signed one is deposited,
# and a copy that names nobody goes to the reviewers.

blind_project <- function() {
  p <- new_project(title = "Chemical mimicry in ants",
                   authors = c("Ada Lovelace", "Alan Turing"))
  in_project(p, sync_licenses(quiet = TRUE))
  md <- file.path(p, "data", "metadata")
  dir.create(md, recursive = TRUE, showWarnings = FALSE)
  writeLines(c("id,name,affiliation,email",
               "0000-0002-1825-0097,Ada Lovelace,University X,ada@example.org",
               ",Alan Turing,University Y,"),
             file.path(md, "creators.csv"))
  jsonlite::write_json(
    list(`@context` = "https://schema.org/", `@type` = "Dataset",
         name = "Chemical mimicry in ants",
         creator = list(list(`@type` = "Person", name = "Ada Lovelace",
                             email = "ada@example.org"),
                        list(`@type` = "Person", name = "Alan Turing"))),
    file.path(md, "dataspice.json"), auto_unbox = TRUE, pretty = TRUE)
  writeLines("<html><body>Ada Lovelace, Alan Turing</body></html>",
             file.path(md, "index_metadata.html"))
  writeLines(c("species,count", "Formica,3"), file.path(p, "data", "ants.csv"))
  p
}

test_that("a double-blind submission gets a compendium that names nobody", {
  p  <- blind_project()
  dc <- file.path(p, "submission", "Oryx", "data_and_code")
  bc <- file.path(p, "submission", "Oryx", "data_and_code_blinded")
  in_project(p, {
    suppressWarnings(.export_data_code(dc, blinded = FALSE))
    expect_no_warning(.blind_compendium(dc, bc))
  })

  # The signed one, as it was: it is the one deposited.
  expect_true(any(grepl("Ada Lovelace", readLines(file.path(dc, "metadata", "creators.csv")))))
  expect_true(any(grepl("Ada Lovelace, Alan Turing", readLines(file.path(dc, "README.txt")),
                        fixed = TRUE)))

  # The copy: as many creators, none of them named, with nothing else on them.
  cr <- utils::read.csv(file.path(bc, "metadata", "creators.csv"),
                        colClasses = "character")
  expect_identical(cr$name, c("Anonymous", "Anonymous"))
  expect_true(all(cr$affiliation == "" & cr$email == "" & cr$id == ""))
  j <- jsonlite::read_json(file.path(bc, "metadata", "dataspice.json"))
  expect_identical(vapply(j$creator, `[[`, "", "name"), c("Anonymous", "Anonymous"))
  expect_identical(j$name, "Chemical mimicry in ants")
  # The page built from the metadata is rebuilt from the copy, or goes.
  html <- file.path(bc, "metadata", "index_metadata.html")
  if (file.exists(html)) expect_false(any(grepl("Lovelace", readLines(html))))
  expect_true(any(grepl("^Copyright \\(c\\) [0-9]{4} The authors$",
                        readLines(file.path(bc, "LICENSE-CODE")))))
  readme <- readLines(file.path(bc, "README.txt"))
  expect_true(any(grepl("Anonymous", readme)))
  expect_false(any(grepl("Lovelace|Turing", readme)))
  # Nothing in it names them any more.
  expect_length(in_project(p, .names_left(bc, .identifiers())), 0L)
  # The data themselves travel untouched.
  expect_identical(readLines(file.path(bc, "data", "ants.csv")),
                   readLines(file.path(dc, "data", "ants.csv")))
})

test_that("it says where the authors are still named, file by file", {
  p  <- blind_project()
  writeLines(c("# Analysis of the mimicry trials, by A. Turing", "x <- 1"),
             file.path(p, "R", "analysis_mimicry.R"))
  writeLines(c("species,observer", "Formica,Lovelace"),
             file.path(p, "data", "observers.csv"))
  dc <- file.path(p, "submission", "Oryx", "data_and_code")
  bc <- file.path(p, "submission", "Oryx", "data_and_code_blinded")
  in_project(p, {
    suppressWarnings(.export_data_code(dc, blinded = FALSE))
    w <- tryCatch(.blind_compendium(dc, bc), warning = conditionMessage)
  })
  expect_match(w, "scripts/analysis_mimicry.R: Turing", fixed = TRUE)
  expect_match(w, "data/observers.csv: Lovelace", fixed = TRUE)
  # The README describes a script by its first comment: it quotes it.
  expect_match(w, "README.txt: Turing", fixed = TRUE)
  expect_no_match(w, "metadata/|LICENSE")
  # The files the package did not write are left as they are.
  expect_identical(readLines(file.path(bc, "scripts", "analysis_mimicry.R"))[1],
                   "# Analysis of the mimicry trials, by A. Turing")
})

test_that("what identifies the authors is searched as whole words", {
  ids <- c("Ada Lovelace", "Long", "a.b@x.org")
  d <- tempfile(); dir.create(d)
  writeLines("Longitude,Latitude", file.path(d, "plots.csv"))
  writeLines("Written by Long.", file.path(d, "notes.txt"))
  writeLines("mail: a.b@x.org", file.path(d, "mail.txt"))
  writeBin(as.raw(c(0, 1, 2)), file.path(d, "Ada Lovelace.bin"))
  left <- .names_left(d, ids)
  expect_setequal(names(left), c("notes.txt", "mail.txt", "Ada Lovelace.bin"))
  expect_identical(left[["notes.txt"]], "Long")
  expect_identical(left[["mail.txt"]], "a.b@x.org")
  # A binary file is not read, but its name is.
  expect_identical(left[["Ada Lovelace.bin"]], "Ada Lovelace")
})

test_that("make_submission() builds both, and a signed call leaves one", {
  code <- code_of(make_submission)
  expect_match(code, ".export_data_code(dc, blinded = FALSE)", fixed = TRUE)
  expect_match(code, "if (blind) { .blind_compendium(dc, bc)", fixed = TRUE)
  expect_match(code, "unlink(c(bc, paste0(bc, \".zip\")), recursive = TRUE)",
               fixed = TRUE)
  # The checklist speaks of the copy only when there is one.
  f <- tempfile(fileext = ".md")
  .write_checklist(f, "Oryx", "Oryx", blinded = TRUE)
  expect_true(any(grepl("data_and_code_blinded.zip", readLines(f), fixed = TRUE)))
  .write_checklist(f, "Oryx", "Oryx", blinded = FALSE)
  expect_false(any(grepl("data_and_code_blinded", readLines(f), fixed = TRUE)))
})

test_that("the blinded renv.lock names no author of any package", {
  # renv records the DESCRIPTION of every package: knitr's contributors
  # include a Smith, and the example's John Smith was reported as still named.
  p  <- blind_project()
  lock <- list(R = list(Version = "4.5.0",
                        Repositories = list(list(Name = "CRAN",
                                                 URL = "https://cloud.r-project.org"))),
               Packages = list(knitr = list(
                 Package = "knitr", Version = "1.50", Source = "Repository",
                 Repository = "CRAN",
                 `Authors@R` = "person('Alan', 'Turing', role = 'ctb')",
                 Author = "Yihui Xie [aut, cre], Alan Turing [ctb]",
                 Maintainer = "Yihui Xie <xie@yihui.name>",
                 URL = "https://github.com/yihui/knitr",
                 BugReports = "https://github.com/yihui/knitr/issues",
                 Requirements = list("R"), Hash = "abc")))
  jsonlite::write_json(lock, file.path(p, "renv.lock"), auto_unbox = TRUE,
                       pretty = TRUE)
  dc <- file.path(p, "submission", "Oryx", "data_and_code")
  bc <- file.path(p, "submission", "Oryx", "data_and_code_blinded")
  in_project(p, {
    suppressWarnings(.export_data_code(dc, blinded = FALSE))
    expect_no_warning(.blind_compendium(dc, bc))
  })
  # The signed one keeps the lockfile as renv wrote it.
  expect_true(any(grepl("Turing", readLines(file.path(dc, "renv.lock")))))
  k <- jsonlite::read_json(file.path(bc, "renv.lock"))$Packages$knitr
  expect_null(k$Author)
  expect_null(k[["Authors@R"]])
  expect_null(k$Maintainer)
  # What renv::restore() reads is left as it was.
  expect_identical(k[c("Package", "Version", "Source", "Repository", "Hash")],
                   lock$Packages$knitr[c("Package", "Version", "Source",
                                         "Repository", "Hash")])
  expect_identical(k$Requirements, list("R"))
  expect_null(k$URL)
  expect_null(k$BugReports)
  # A lockfile that is not JSON is left alone.
  f <- tempfile(); writeLines("not json", f)
  .lock_without_people(f)
  expect_identical(readLines(f), "not json")
})

test_that("the blinded renv.lock gives away no GitHub account", {
  # Installed from GitHub, a package's record names the account it came
  # from, in its pages and its remote; nothing looked for it, so the author
  # of a package who used it in a paper was named to the reviewers silently.
  p <- blind_project()
  ms <- readLines(file.path(p, "manuscript.qmd"))
  writeLines(sub("correspondent@example.org", "adalovelace1815@example.org", ms,
                 fixed = TRUE), file.path(p, "manuscript.qmd"))
  gh <- function(pkg, user) list(Package = pkg, Version = "1.0", Source = "GitHub",
    RemoteType = "github", RemoteHost = "api.github.com", RemoteRepo = pkg,
    RemoteUsername = user, RemoteSha = "abc",
    URL = paste0("https://github.com/", user, "/", pkg),
    BugReports = paste0("https://github.com/", user, "/", pkg, "/issues"))
  lock <- list(R = list(Version = "4.5.0"),
               Packages = list(easypaper = gh("easypaper", "adalovelace1815"),
                               antstats  = gh("antstats", "adalovelace1815"),
                               other     = gh("other", "someoneelse")))
  jsonlite::write_json(lock, file.path(p, "renv.lock"), auto_unbox = TRUE, pretty = TRUE)
  dc <- file.path(p, "submission", "Oryx", "data_and_code")
  bc <- file.path(p, "submission", "Oryx", "data_and_code_blinded")
  in_project(p, {
    expect_true("adalovelace1815" %in% .identifiers())
    suppressWarnings(.export_data_code(dc, blinded = FALSE))
    w <- tryCatch(.blind_compendium(dc, bc), warning = conditionMessage)
  })
  pk <- jsonlite::read_json(file.path(bc, "renv.lock"))$Packages
  # easypaper goes: the analysis does not use it.
  expect_null(pk$easypaper)
  expect_setequal(names(pk), c("antstats", "other"))
  # The pages go from every package; the remote stays, renv needs it.
  expect_null(pk$antstats$URL)
  expect_identical(pk$other$RemoteUsername, "someoneelse")
  # A package of an author's own is reported, with what to do.
  expect_match(w, "renv.lock: adalovelace1815", fixed = TRUE)
  expect_match(w, "installed from an author's GitHub account", fixed = TRUE)
  # The signed one keeps it all.
  expect_false(is.null(jsonlite::read_json(file.path(dc, "renv.lock"))$Packages$easypaper))
})

test_that("the accounts of the authors are what they are known by", {
  p <- new_project(title = "Ants")
  in_project(p, {
    expect_identical(.accounts(c("adalovelace@x.org", "al@x.org", NA)), "adalovelace")
    expect_identical(.accounts(character(0)), character(0))
  })
  # The owner of the project's GitHub repository, when it has one.
  skip_if(!nzchar(Sys.which("git")))
  system2("git", c("-C", shQuote(p), "init", "-q"))
  system2("git", c("-C", shQuote(p), "remote", "add", "origin",
                   "git@github.com:antlab-xyz/ants-paper.git"))
  system2("git", c("-C", shQuote(p), "remote", "add", "mirror",
                   "https://github.com/someone-else/ants-paper"))
  expect_setequal(in_project(p, .accounts()), c("antlab-xyz", "someone-else"))
})
