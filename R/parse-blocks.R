# Split an R source file into "blocks": a contiguous run of #' comment
# lines immediately followed by a top-level expression (function or object
# assignment). This mirrors the model described in vignettes/roxygen2.Rmd:
# a block is a sequence of lines starting with #', ends when it hits code,
# and blank lines break the association (plain, non-roxygen comment lines
# in between are skipped over, see collect_roxygen_comment() below).

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
# run of trimmed lines that begin with "#'". Plain (non-roxygen) comment
# lines - e.g. usethis's "## usethis namespace: start/end" markers around
# an injected `@useDynLib`/`@import` block - are skipped over rather than
# treated as breaking the association, since they carry no roxygen content
# of their own. Stops at the first line that is blank or is code.
collect_roxygen_comment <- function(lines, start_line) {
  is_roxygen <- function(line) grepl("^[ \t]*#'", line)
  is_plain_comment <- function(line) grepl("^[ \t]*#(?!')", line, perl = TRUE)

  i <- start_line - 1
  collected <- character()
  while (i >= 1) {
    line <- lines[i]
    if (is_roxygen(line)) {
      collected <- c(line, collected)
      i <- i - 1
    } else if (is_plain_comment(line)) {
      i <- i - 1
    } else {
      break
    }
  }
  collected
}
