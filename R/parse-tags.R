# Convert the raw "#' ..." lines of a block into an intro (title /
# description / details) plus a list of @tag entries. No markdown
# processing, no Rd-in-roxygen parsing: tag content is used close to
# verbatim, which keeps this file simple and avoids "magic".

strip_comment_prefix <- function(raw) {
  sub("^[ \t]*#'[ ]?", "", raw)
}

parse_block_tags <- function(raw) {
  content <- strip_comment_prefix(raw)
  is_tag <- grepl("^@[a-zA-Z][a-zA-Z0-9]*(\\s|$)", content)
  tag_idx <- which(is_tag)

  if (length(tag_idx) == 0) {
    return(list(intro = content, tags = list()))
  }

  intro <- content[seq_len(tag_idx[1] - 1)]

  bounds <- c(tag_idx, length(content) + 1)
  tags <- vector("list", length(tag_idx))
  for (i in seq_along(tag_idx)) {
    segment <- content[bounds[i]:(bounds[i + 1] - 1)]
    m <- regmatches(segment[1], regexec("^@([a-zA-Z][a-zA-Z0-9]*)[ \t]*(.*)$", segment[1]))[[1]]
    tag_name <- m[2]
    first_line <- m[3]
    rest <- if (length(segment) > 1) segment[-1] else character()
    value <- c(first_line, rest)
    # drop leading/trailing blank lines within a tag's value (but keep
    # blank lines *between* non-blank ones, e.g. paragraph breaks)
    if (length(value) > 0) {
      non_blank <- which(str_trim(value) != "")
      value <- if (length(non_blank) > 0) {
        value[min(non_blank):max(non_blank)]
      } else {
        character()
      }
    }
    tags[[i]] <- list(tag = tag_name, value = value)
  }

  list(intro = intro, tags = tags)
}

# Fetch all values for a given tag name (e.g. multiple @param / @importFrom).
tags_named <- function(tags, name) {
  Filter(function(t) identical(t$tag, name), tags)
}

# Fetch the first value (joined as a single string) for a tag, or NULL.
tag_value <- function(tags, name) {
  found <- tags_named(tags, name)
  if (length(found) == 0) {
    return(NULL)
  }
  paste(found[[1]]$value, collapse = "\n")
}

tag_present <- function(tags, name) {
  length(tags_named(tags, name)) > 0
}
