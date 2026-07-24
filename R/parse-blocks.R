# Split an R source file into "blocks": a contiguous run of #' comment
# lines immediately followed by a top-level expression (function or object
# assignment). This mirrors the model described in vignettes/roxygen2.Rmd:
# a block is a sequence of lines starting with #', ends when it hits code,
# and blank lines/plain comments in between break the association.

parse_file_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  exprs <- tryCatch(
    parse(path, keep.source = TRUE),
    error = function(e) die("Failed to parse %s: %s", path, conditionMessage(e))
  )
  if (length(exprs) == 0) {
    return(list())
  }

  refs <- attr(exprs, "srcref")
  blocks <- list()

  for (i in seq_along(exprs)) {
    start_line <- refs[[i]][1]
    comment_lines <- collect_roxygen_comment(lines, start_line)
    if (length(comment_lines) == 0) {
      next
    }
    blocks[[length(blocks) + 1]] <- list(
      raw = comment_lines,
      call = exprs[[i]],
      file = path,
      line = start_line
    )
  }

  blocks
}

# Walk upwards from the line before `start_line`, collecting a contiguous
# run of trimmed lines that begin with "#'". Stops at the first line that
# is blank, is a plain comment, or is code.
collect_roxygen_comment <- function(lines, start_line) {
  is_roxygen <- function(line) grepl("^[ \t]*#'", line)

  i <- start_line - 1
  collected <- character()
  while (i >= 1 && is_roxygen(lines[i])) {
    collected <- c(lines[i], collected)
    i <- i - 1
  }
  collected
}
