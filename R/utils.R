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

# Parse an @exportS3Method tag's value (e.g. "print event_loop") into
# generic/class parts. When the tag has no value, falls back to splitting
# the block's own dotted name (e.g. "print.event_loop") on the first dot.
# Shared by the namespace roclet (for S3method() entries) and the Rd
# roclet (for \method{}{} usage markup), so both stay in sync.
s3_method_parts <- function(tag_val, block_name) {
  tag_val <- str_trim(if (is.null(tag_val)) "" else tag_val)
  if (nzchar(tag_val)) {
    parts <- strsplit(tag_val, "[ \t]+")[[1]]
    generic <- parts[1]
    class <- if (length(parts) > 1) parts[2] else NA_character_
  } else {
    parts <- strsplit(block_name, "\\.", fixed = FALSE)[[1]]
    generic <- parts[1]
    class <- paste(parts[-1], collapse = ".")
  }
  list(generic = generic, class = class)
}
