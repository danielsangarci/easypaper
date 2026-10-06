# The compendium of a double-blind submission: the signed one is deposited,
# and a copy that names nobody goes to the reviewers.

blind_project <- function() {
  p <- new_project(title = "Chemical mimicry in ants",
                   authors = c("Ada Lovelace", "Alan Turing"))
  in_project(p, sync_licenses(quiet = TRUE))
  md <- file.path(p, "data", "metadata")
  dir.create(md, recursive = TRUE, showWarnings = FALSE)
  writeLines(c("id,name,affiliation,email",
               "0000-0000-0000-0000,Ada Lovelace,University X,ada@example.org",
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
                        readLines(file.path(bc, "LICENSE-CODE.txt")))))
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
  expect_no_match(w, "metadata/|LICENSE.txt")
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

test_that("make_submission() builds both, and a signed call only one", {
  code <- code_of(make_submission)
  expect_match(code, ".export_data_code(dc, blinded = FALSE)", fixed = TRUE)
  expect_match(code, "if (blind) { .blind_compendium(dc, bc)", fixed = TRUE)
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

test_that("the cover letter fills in what the project knows", {
  # The date, in English whatever the locale; who signs it.
  expect_identical(.letter_date(as.Date("2026-10-03")), "3 October 2026")
  a <- list(list(name = "Ada Lovelace"),
            list(name = "Alan Turing", corresponding = TRUE))
  expect_identical(.signature(list(author = a)),
                   "Alan Turing, on behalf of all authors")
  # No author marked: the first one signs; alone, on behalf of no one.
  expect_identical(.signature(list(author = list(list(name = "Ada")))), "Ada")
  expect_identical(.signature(list(author = c("Ada", "Alan"))),
                   "Ada, on behalf of all authors")
  expect_match(.signature(list()), "[Corresponding author", fixed = TRUE)

  skip_on_cran()
  skip_if_not(nzchar(Sys.getenv("QUARTO_PATH")) ||
                nzchar(Sys.which("quarto")), "Quarto is not available")
  p <- new_project(title = "Chemical mimicry in ants",
                   authors = c("Ada Lovelace", "Alan Turing"))
  f <- file.path(p, "letter.docx")
  in_project(p, .write_cover_letter(f, "Journal of Ecology"))
  plain <- function(f) {
    out <- tempfile(fileext = ".txt")
    rmarkdown::pandoc_convert(f, to = "plain", output = out)
    paste(readLines(out), collapse = " ")
  }
  txt <- plain(f)
  expect_match(txt, "Chemical mimicry in ants", fixed = TRUE)
  expect_match(txt, "Ada Lovelace, on behalf of all authors", fixed = TRUE)
  expect_match(txt, .letter_date(), fixed = TRUE)
  expect_false(grepl("[TITLE]", txt, fixed = TRUE))
  # No DOI reserved yet: the placeholder stays, and deposit_zenodo() fills it.
  expect_match(txt, "[repository DOI]", fixed = TRUE)
  dir.create(file.path(p, "submission", "JoE"), recursive = TRUE)
  file.copy(f, file.path(p, "submission", "JoE", "cover_letter_JoE.docx"))
  done <- in_project(p, .fill_doi_letters("10.5281/zenodo.123"))
  expect_identical(done, "JoE/cover_letter_JoE.docx")
  filled <- plain(file.path(p, "submission", "JoE", "cover_letter_JoE.docx"))
  expect_match(filled, "https://doi.org/10.5281/zenodo.123", fixed = TRUE)
  expect_false(grepl("[repository DOI]", filled, fixed = TRUE))
  # Still a .docx, with [Content_Types].xml first.
  expect_identical(zip::zip_list(file.path(p, "submission", "JoE",
                                           "cover_letter_JoE.docx"))$filename[1],
                   "[Content_Types].xml")
  # Written after the deposit, a letter carries the DOI from the start.
  in_project(p, .set_config("data-doi", "10.5281/zenodo.456"))
  g <- file.path(p, "letter2.docx")
  in_project(p, .write_cover_letter(g, "Journal of Ecology"))
  expect_match(plain(g), "https://doi.org/10.5281/zenodo.456", fixed = TRUE)
})

test_that("the compendium carries a description compiled from its files now", {
  # Not the dataspice.json left by the last edit_metadata("write"), weeks
  # ago: the one the .csv files make today.
  p  <- blind_project()
  md <- file.path(p, "data", "metadata")
  stale <- jsonlite::read_json(file.path(md, "dataspice.json"))
  expect_null(stale$creator[[1]]$affiliation)
  dc <- file.path(p, "submission", "Oryx", "data_and_code")
  in_project(p, suppressWarnings(suppressMessages(.export_data_code(dc, blinded = FALSE))))
  j <- jsonlite::read_json(file.path(dc, "metadata", "dataspice.json"))
  ada <- Filter(function(x) identical(x$name, "Ada Lovelace"), j$creator)[[1]]
  expect_identical(ada$affiliation, "University X")
  expect_true(file.exists(file.path(dc, "metadata", "index_metadata.html")))

  # A project with no data has nothing to describe, and says so only when asked.
  q <- new_project()
  dq <- file.path(q, "submission", "X", "data_and_code")
  said <- character(0)
  withCallingHandlers(
    in_project(q, suppressMessages(.export_data_code(dq, blinded = FALSE))),
    warning = function(w) {
      said <<- c(said, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_false(any(grepl("metadata", said)))
  expect_error(suppressMessages(edit_metadata("write", path = q)), "no data")
})

test_that("a second submission starts its cover letter from the first one", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.getenv("QUARTO_PATH")) ||
                nzchar(Sys.which("quarto")), "Quarto is not available")
  plain <- function(f) {
    out <- tempfile(fileext = ".txt")
    rmarkdown::pandoc_convert(normalizePath(f), to = "plain", output = out,
                              options = "--wrap=none")
    paste(readLines(out), collapse = " ")
  }
  p <- new_project(title = "Chemical mimicry in ants",
                   authors = c("Ada Lovelace", "Alan Turing"))
  first <- file.path(p, "submission", "JoE", "cover_letter_JoE.docx")
  dir.create(dirname(first), recursive = TRUE)
  in_project(p, .write_cover_letter(first, "Journal of Ecology"))
  # The author writes the letter: what they found, in their own words.
  d <- file.path(tempdir(), "edit_letter"); unlink(d, recursive = TRUE)
  parts <- zip::zip_list(first)$filename
  utils::unzip(first, exdir = d)
  x <- file.path(d, "word", "document.xml")
  xml <- readChar(x, file.size(x), useBytes = TRUE)
  xml <- sub("[The main result, with the number.]",
             "Ants mimic their hosts in 9 of 10 colonies.", xml, fixed = TRUE)
  writeChar(xml, x, eos = NULL, useBytes = TRUE)
  zip::zip(normalizePath(first), files = parts, root = d, mode = "mirror")
  Sys.setFileTime(first, Sys.time() - 3600)

  # The paper goes to another journal, under a new title, with its DOI now.
  ms <- file.path(p, "manuscript.qmd")
  writeLines(sub("Chemical mimicry in ants", "Chemical mimicry in social insects",
                 readLines(ms), fixed = TRUE), ms)
  in_project(p, .set_config("data-doi", "10.5281/zenodo.789"))
  second <- file.path(p, "submission", "EL", "cover_letter_EL.docx")
  dir.create(dirname(second), recursive = TRUE)
  expect_message(in_project(p, .write_cover_letter(second, "Ecology Letters")),
                 "cover_letter_JoE.docx")
  txt <- plain(second)
  expect_match(txt, "Ants mimic their hosts in 9 of 10 colonies.", fixed = TRUE)
  expect_match(txt, "Why Ecology Letters", fixed = TRUE)
  expect_false(grepl("Journal of Ecology", txt, fixed = TRUE))
  expect_match(txt, "Chemical mimicry in social insects", fixed = TRUE)
  expect_match(txt, "https://doi.org/10.5281/zenodo.789", fixed = TRUE)
  expect_match(txt, .letter_date(), fixed = TRUE)
  expect_match(txt, "Ada Lovelace, on behalf of all authors", fixed = TRUE)
  # The first one is left as it was.
  expect_match(plain(first), "Journal of Ecology", fixed = TRUE)
})

test_that("a second submission to the same journal is the next version", {
  p <- new_project()
  s <- file.path(p, "submission")
  in_project(p, expect_identical(.next_label("JournalofEcology"), "JournalofEcology"))
  dir.create(file.path(s, "JournalofEcology"), recursive = TRUE)
  expect_message(v2 <- in_project(p, .next_label("JournalofEcology")), "stays as it is")
  expect_identical(v2, "JournalofEcology_v2")
  dir.create(file.path(s, "JournalofEcology_v2"))
  dir.create(file.path(s, "JournalofEcology_v7"))
  # After the highest, whichever label of the paper is asked for.
  expect_identical(suppressMessages(in_project(p, .next_label("JournalofEcology"))),
                   "JournalofEcology_v8")
  expect_identical(suppressMessages(in_project(p, .next_label("JournalofEcology_v2"))),
                   "JournalofEcology_v8")
  # Another journal, or a label not taken, is used as it is.
  expect_identical(in_project(p, .next_label("JournalofEcologyLetters")),
                   "JournalofEcologyLetters")
  expect_identical(in_project(p, .next_label("JournalofEcology_v3")),
                   "JournalofEcology_v3")
  # Both deliverables ask for it.
  expect_match(code_of(make_submission), "label <- .next_label(label)", fixed = TRUE)
  expect_match(code_of(make_preprint), "label <- .next_label(label)", fixed = TRUE)
})

test_that("the compendium's scripts hold the setup once, inside analysis_code.R", {
  p  <- blind_project()
  in_project(p, suppressMessages(export_code()))
  writeLines("x <- 1", file.path(p, "R", "analysis_extra.R"))
  dc <- file.path(p, "submission", "Oryx", "data_and_code")
  in_project(p, suppressWarnings(suppressMessages(.export_data_code(dc, blinded = FALSE))))
  s <- list.files(file.path(dc, "scripts"))
  expect_true(all(c("analysis_code.R", "analysis_extra.R") %in% s))
  expect_false("setup.R" %in% s)
  # analysis_code.R opens with it, and the README says so.
  expect_true(any(grepl("SETUP: R/setup.R",
                        readLines(file.path(dc, "scripts", "analysis_code.R")), fixed = TRUE)))
  readme <- paste(readLines(file.path(dc, "README.txt")), collapse = " ")
  expect_false(grepl("sources 'scripts/setup.R'", readme, fixed = TRUE))
  expect_match(readme, "opens with the setup", fixed = TRUE)
})
