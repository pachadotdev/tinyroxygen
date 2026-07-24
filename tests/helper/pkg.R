# Shared helper for tests/*.R, not itself run as a standalone test since
# R CMD check only sources *.R files directly under tests/, not
# subdirectories. Mirrors what roxygen2's `roc_proc_text()` gives its own
# testthat suite, but building a tiny real package directory and calling
# the public roxygenise() entry point end-to-end (no testthat needed).

make_test_pkg <- function(..., desc_extra = character()) {
  r_files <- list(...)
  pkgdir <- tempfile("tinyroxygenpkg")
  dir.create(file.path(pkgdir, "R"), recursive = TRUE)
  writeLines(
    c("Package: testpkg", "Version: 0.1", "License: MIT", desc_extra),
    file.path(pkgdir, "DESCRIPTION")
  )
  for (fname in names(r_files)) {
    writeLines(r_files[[fname]], file.path(pkgdir, "R", fname))
  }
  pkgdir
}

read_rd <- function(pkgdir, topic) {
  path <- file.path(pkgdir, "man", paste0(topic, ".Rd"))
  stopifnot(file.exists(path))
  readLines(path)
}

read_ns <- function(pkgdir) {
  readLines(file.path(pkgdir, "NAMESPACE"))
}

# extract the body of a single \tag{...} section (first match), one entry
# per line, for easy comparison in tests
rd_section <- function(rd, tag) {
  start <- which(rd == sprintf("\\%s{", tag))
  if (length(start) == 0) {
    return(NULL)
  }
  end <- start[1] + which(rd[-seq_len(start[1])] == "}")[1]
  rd[(start[1] + 1):(end - 1)]
}
