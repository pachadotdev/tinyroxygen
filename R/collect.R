# Turn raw per-file blocks into fully annotated blocks used by both
# roclets (Rd and NAMESPACE).

collect_blocks <- function(pkgdir) {
  files <- pkg_r_files(pkgdir)
  blocks <- list()
  for (path in files) {
    for (raw_block in parse_file_blocks(path)) {
      parsed <- parse_block_tags(raw_block$raw)
      info <- object_info(raw_block$call)

      name <- tag_value(parsed$tags, "name")
      if (is.null(name)) {
        name <- if (identical(info$name, "_PACKAGE")) {
          paste0(pkg_name(pkgdir), "-package")
        } else {
          info$name
        }
      }

      blocks[[length(blocks) + 1]] <- list(
        name = name,
        is_function = info$is_function,
        usage = info$usage,
        intro = parsed$intro,
        tags = parsed$tags,
        file = raw_block$file,
        line = raw_block$line
      )
    }
  }
  blocks
}

# Group blocks into documentation topics: one topic per @rdname (or per
# object name when @rdname is absent). Blocks that can't be assigned a
# name (no @name, no @rdname, unrecognised object) are dropped with a
# warning, since there is nowhere to write them.
group_blocks_by_topic <- function(blocks) {
  topics <- list()
  order <- character()

  for (b in blocks) {
    key <- tag_value(b$tags, "rdname")
    if (is.null(key)) key <- b$name
    if (is.null(key) || is.na(key) || !nzchar(key)) {
      warning(sprintf(
        "Skipping undocumented-name block at %s:%d (no @name/@rdname and could not infer one)",
        b$file, b$line
      ), call. = FALSE)
      next
    }
    if (is.null(topics[[key]])) {
      order <- c(order, key)
      topics[[key]] <- list()
    }
    topics[[key]][[length(topics[[key]]) + 1]] <- b
  }

  topics[order]
}
