# Markdown -> Rd conversion, opt-in via the @md tag (see roclet-rd.R). Parses
# text with a vendored, trimmed-down copy of cmark (src/cmark/, vendored by
# scripts/cmark.sh) via a single .Call, then renders the resulting AST into
# Rd markup here in R. Deliberately supports only a small, unambiguous
# subset of Markdown: paragraphs, *emphasis*, **strong**, `code` spans,
# fenced/indented code blocks, [links](url), bullet/ordered lists, line
# breaks, and roxygen2-style topic autolinks ([fun()], [obj], [pkg::fun()],
# [text][ref] - see add_linkrefs_to_md()/render_topic_link() below). No
# tables, headings, images, or raw HTML - keep Rd output simple and
# predictable.

escape_rd_text <- function(x) {
  if (is.null(x)) return(x)
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("{", "\\{", x, fixed = TRUE)
  x <- gsub("}", "\\}", x, fixed = TRUE)
  gsub("%", "\\%", x, fixed = TRUE)
}

# roxygen2-style topic autolinks ([fun()], [obj], [pkg::fun()], [text][ref])
# are plain CommonMark reference-style links under the hood: [ref] and
# [text][ref] both resolve against a "[ref]: <url>" reference definition.
# We scan the source text for bracket references and append a synthetic
# reference definition for each one, using a "R:"-prefixed, URL-encoded
# destination as a marker; render_topic_link() below recognises that
# marker and renders \link{}/\code{\link{}} instead of \href{}. Ported
# (simplified: no cross-package existence checks) from roxygen2's own
# R/markdown-link.R.
add_linkrefs_to_md <- function(text) {
  ref_lines <- get_md_linkrefs(text)
  if (length(ref_lines) == 0) return(text)
  paste0(text, "\n\n", paste0(ref_lines, collapse = "\n"), "\n")
}

get_md_linkrefs <- function(text) {
  refs <- regmatches(
    text,
    gregexec(
      paste0(
        "(?x)",
        "(?<=[^\\]\\\\]|^)", # must not be preceded by ] or \
        "\\[([^\\]\\[]+)\\]", # match anything inside of []
        "(?:\\[([^\\]\\[]+)\\])?", # match optional second pair of []
        "(?=[^\\[{]|$)" # must not be followed by [ or {
      ),
      text,
      perl = TRUE
    )
  )[[1]]
  if (length(refs) == 0) return(character())
  refs <- t(refs)

  # for the [fun] form the link text is the same as the destination
  refs[, 3] <- ifelse(refs[, 3] == "", refs[, 2], refs[, 3])

  refs_encoded <- vapply(refs[, 3], utils::URLencode, character(1))
  paste0("[", refs[, 3], "]: R:", refs_encoded)
}

render_children <- function(node) {
  paste(vapply(node$children, render_node, character(1)), collapse = "")
}

# Render a resolved topic autolink ([fun()], [obj], [pkg::fun()],
# [text][ref], ...) to \link{}/\link[]{}, wrapped in \code{} when the
# destination looks like a function call or was written as `code`.
render_topic_link <- function(node) {
  destination <- utils::URLdecode(sub("^R:", "", node$url))
  contents <- node$children

  is_code <- length(contents) == 1 && identical(contents[[1]]$type, "code")
  if (is_code) {
    text_plain <- contents[[1]]$literal
    destination <- sub("`$", "", sub("^`", "", destination))
    has_link_text <- !identical(text_plain, destination)
  } else {
    text_plain <- paste(vapply(contents, function(c) {
      if (!is.na(c$literal)) c$literal else ""
    }, character(1)), collapse = "")
    has_link_text <- !identical(text_plain, destination) ||
      any(vapply(contents, function(c) !identical(c$type, "text"), logical(1)))
  }

  is_code <- is_code || (grepl("[(][)]$", destination) && !has_link_text)

  pkg <- NA_character_
  fun <- destination
  if (grepl("::", destination, fixed = TRUE)) {
    parts <- strsplit(destination, "::", fixed = TRUE)[[1]]
    pkg <- parts[1]
    fun <- parts[2]
  }
  topic <- sub("[(][)]$", "", fun)
  if (!has_link_text && is.na(pkg) && grepl("-class$", destination)) {
    fun <- sub("-class$", "", fun)
    topic <- fun
  }

  if (!has_link_text) {
    text <- if (!is.na(pkg)) paste0(pkg, "::", fun) else fun
    text <- escape_rd_text(text)
  } else {
    text <- render_children(node)
  }

  rd_topic_link(pkg, escape_rd_text(topic), text, code = is_code)
}

rd_topic_link <- function(pkg, topic, text, code = FALSE) {
  out <- if (is.na(pkg) && identical(topic, text)) {
    sprintf("\\link{%s}", text)
  } else {
    anchor <- if (is.na(pkg)) paste0("=", topic) else paste0(pkg, ":", topic)
    sprintf("\\link[%s]{%s}", anchor, text)
  }
  if (code) sprintf("\\code{%s}", out) else out
}

render_node <- function(node) {
  switch(node$type,
    document = paste(vapply(node$children, render_node, character(1)), collapse = "\n\n"),
    paragraph = render_children(node),
    text = escape_rd_text(node$literal),
    emph = sprintf("\\emph{%s}", render_children(node)),
    strong = sprintf("\\strong{%s}", render_children(node)),
    code = sprintf("\\code{%s}", escape_rd_text(node$literal)),
    code_block = sprintf("\\preformatted{%s}", escape_rd_text(node$literal)),
    link = if (startsWith(node$url, "R:")) {
      render_topic_link(node)
    } else {
      sprintf("\\href{%s}{%s}", node$url, render_children(node))
    },
    softbreak = " ",
    linebreak = " ",
    list = {
      env <- if (identical(node$list_type, "ordered")) "enumerate" else "itemize"
      items <- vapply(node$children, function(item) {
        sprintf("\\item %s", render_children(item))
      }, character(1))
      sprintf("\\%s{\n%s\n}", env, paste(items, collapse = "\n"))
    },
    render_children(node) # fallback for item/block_quote/etc: just concatenate children
  )
}

# Convert a Markdown string (or character vector of lines) to Rd markup.
markdown_to_rd <- function(text) {
  text <- enc2utf8(paste(text, collapse = "\n"))
  text <- add_linkrefs_to_md(text)
  ast <- .Call(R_parse_markdown, text)
  render_node(ast)
}

# Package-wide Markdown default, read from DESCRIPTION's
# `Config/tinyroxygen/markdown: TRUE` field (tinyroxygen's own field, not
# roxygen2's - the two packages don't share config). Set it once in
# DESCRIPTION to turn on Markdown for every topic, instead of adding @md
# to each block individually.
pkg_markdown_default <- function(pkgdir) {
  desc_path <- file.path(pkgdir, "DESCRIPTION")
  if (!file.exists(desc_path)) return(FALSE)
  fields <- tryCatch(
    read.dcf(desc_path, fields = "Config/tinyroxygen/markdown")[1, 1],
    error = function(e) NA_character_
  )
  if (is.na(fields)) return(FALSE)
  isTRUE(as.logical(toupper(str_trim(fields))))
}

