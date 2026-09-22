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
      # `name` is the *documentation* topic name (overridden by @name/
      # @rdname, e.g. several functions grouped under one shared Rd page)
      # and is what the Rd roclet should use. The NAMESPACE roclet must
      # never use it as an export/S3method/exportClass/exportMethod
      # fallback though - it needs the object's own name (`obj_name`),
      # otherwise a bare @export inside a block that also carries a
      # shared @name/@rdname would export the doc topic name instead of
      # the actual function.

      blocks[[length(blocks) + 1]] <- list(
        name = name,
        obj_name = info$name,
        is_function = info$is_function,
        usage = info$usage,
        arg_names = info$arg_names,
        s3_generic = info$s3_generic,
        intro = parsed$intro,
        tags = parsed$tags,
        file = raw_block$file,
        line = raw_block$line
      )
    }
  }

  generic_names <- unique(vapply(
    blocks,
    function(b) if (length(b$s3_generic) == 0L || is.na(b$s3_generic)) "" else b$s3_generic,
    character(1)
  ))
  generic_names <- generic_names[nzchar(generic_names)]
  for (i in seq_along(blocks)) {
    b <- blocks[[i]]
    bare_export <- tag_present(b$tags, "export") &&
      !nzchar(str_trim(tag_value(b$tags, "export")))
    inferred <- FALSE
    if (bare_export && length(generic_names) > 0L &&
        !is.null(b$obj_name) && !is.na(b$obj_name)) {
      match <- regexec("^([^\\.]+)\\.(.+)$", b$obj_name)
      parts <- regmatches(b$obj_name, match)[[1]]
      inferred <- length(parts) == 3L && parts[2] %in% generic_names
    }
    blocks[[i]]$is_s3_method <- inferred
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
    has_s3_method_docs <- nzchar(str_trim(paste(b$intro, collapse = ""))) ||
      any(vapply(b$tags, function(t) !identical(t$tag, "export"), logical(1)))
    if (isTRUE(b$is_s3_method) && !has_s3_method_docs) {
      next
    }
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
