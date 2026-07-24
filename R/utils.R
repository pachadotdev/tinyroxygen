# Internal helpers shared across tinyroxygen's parser and roclets.
# No non-base dependencies on purpose.

pkg_r_files <- function(pkgdir) {
  r_dir <- file.path(pkgdir, "R")
  if (!dir.exists(r_dir)) {
    return(character())
  }
  files <- list.files(r_dir, pattern = "\\.[rR]$", full.names = TRUE)
  sort(files)
}

pkg_man_dir <- function(pkgdir) {
  man_dir <- file.path(pkgdir, "man")
  if (!dir.exists(man_dir)) {
    dir.create(man_dir)
  }
  man_dir
}

# Package name from DESCRIPTION, used to name the "_PACKAGE" doc topic.
pkg_name <- function(pkgdir) {
  read.dcf(file.path(pkgdir, "DESCRIPTION"), fields = "Package")[1, 1]
}

# trim leading/trailing whitespace
str_trim <- function(x) {
  gsub("^[ \t]+|[ \t]+$", "", x)
}

# collapse a character vector of lines into paragraphs split by blank lines
split_paragraphs <- function(lines) {
  lines <- str_trim(lines)
  if (length(lines) == 0 || all(lines == "")) {
    return(character())
  }
  # drop leading/trailing blank lines
  non_blank <- which(lines != "")
  lines <- lines[min(non_blank):max(non_blank)]
  is_blank <- lines == ""
  groups <- cumsum(is_blank)
  paragraphs <- split(lines[!is_blank], groups[!is_blank])
  vapply(paragraphs, paste, character(1), collapse = "\n")
}

die <- function(...) {
  stop(sprintf(...), call. = FALSE)
}
