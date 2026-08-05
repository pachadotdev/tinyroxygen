# Rd roclet: turns a documentation topic (one or more annotated blocks
# sharing a @name/@rdname) into a single .Rd file. Text is treated as plain
# text/Rd markup (\code{}, \link{}, ...) by default, same as pre-markdown
# roxygen2. Add @md to a block to opt that topic into Markdown syntax for
# its title/description/details/params/return/seealso (see R/markdown.R).

escape_rd_percent <- function(x) {
  if (is.null(x)) return(x)
  gsub("(?<!\\\\)%", "\\\\%", x, perl = TRUE)
}

# @examples content is raw R code, written into \examples{} without any
# markdown/Rd-macro rendering. But \examples{} is still parsed by Rd, so a
# literal backslash must be doubled (otherwise e.g. "\\s" in a regex is
# read back as the invalid escape "\s") and a literal % must be escaped
# (otherwise Rd treats it as a comment and silently drops the rest of the
# line, e.g. in `x %in% y` or `5 %% 2`). Backslashes are escaped first so
# the backslash introduced by percent-escaping isn't doubled again.
escape_rd_examples <- function(x) {
  if (is.null(x)) return(x)
  x <- gsub("\\\\", "\\\\\\\\", x, fixed = TRUE)
  gsub("%", "\\\\%", x, fixed = TRUE)
}

rd_block <- function(tag, body) {
  if (is.null(body) || !nzchar(str_trim(paste(body, collapse = "")))) {
    return(character())
  }
  c(sprintf("\\%s{", tag), body, "}", "")
}

# S3 methods must be shown in \usage{} with \method{generic}{class}(...)
# markup instead of their full dotted name (CRAN's Rd checks reject the
# full name). Only applies to blocks tagged @exportS3Method; other
# functions keep their plain "name(args)" usage as-is.
s3_method_usage <- function(b) {
  if (!tag_present(b$tags, "exportS3Method")) {
    return(b$usage)
  }
  parts <- s3_method_parts(tag_value(b$tags, "exportS3Method"), b$name)
  if (is.na(parts$class) || !nzchar(parts$class)) {
    return(b$usage)
  }
  prefix <- paste0(b$name, "(")
  if (!startsWith(b$usage, prefix)) {
    return(b$usage)
  }
  paste0(sprintf("\\method{%s}{%s}", parts$generic, parts$class), substring(b$usage, nchar(b$name) + 1))
}

# Build the \description / \details from a block's intro text (paragraphs
# separated by blank lines) unless overridden by explicit @description /
# @details tags.
intro_sections <- function(block) {
  paragraphs <- split_paragraphs(block$intro)
  title <- if (length(paragraphs) >= 1) paragraphs[1] else ""
  description <- if (length(paragraphs) >= 2) paragraphs[2] else ""
  details <- if (length(paragraphs) >= 3) paste(paragraphs[-(1:2)], collapse = "\n\n") else ""

  title_tag <- tag_value(block$tags, "title")
  desc_tag <- tag_value(block$tags, "description")
  details_tag <- tag_value(block$tags, "details")

  list(
    title = if (!is.null(title_tag)) title_tag else title,
    description = if (!is.null(desc_tag)) desc_tag else description,
    details = if (!is.null(details_tag)) details_tag else details
  )
}

parse_param_tag <- function(entry) {
  first_line <- entry$value[1]
  m <- regmatches(first_line, regexec("^([^ \t]+)[ \t]*(.*)$", first_line))[[1]]
  names_part <- m[2]
  desc_first <- m[3]
  rest <- if (length(entry$value) > 1) entry$value[-1] else character()
  desc <- paste(c(desc_first, rest), collapse = "\n")
  list(names = str_trim(strsplit(names_part, ",")[[1]]), description = desc)
}

# Map object name -> named list of param description, gathered from every
# block's own @param tags across the whole package. Used to resolve
# @inheritParams. Only same-package lookups by bare object name are
# supported: a `pkg::fun` source has its `pkg::` prefix stripped and is
# looked up as if it were local (no cross-package resolution).
build_param_index <- function(blocks) {
  index <- list()
  for (b in blocks) {
    if (is.null(b$name) || is.na(b$name) || !nzchar(b$name)) next
    params <- list()
    for (p in tags_named(b$tags, "param")) {
      parsed <- parse_param_tag(p)
      for (nm in parsed$names) {
        if (is.null(params[[nm]])) params[[nm]] <- parsed$description
      }
    }
    if (length(params) == 0) next
    existing <- index[[b$name]]
    if (is.null(existing)) {
      index[[b$name]] <- params
    } else {
      for (nm in names(params)) {
        if (is.null(existing[[nm]])) existing[[nm]] <- params[[nm]]
      }
      index[[b$name]] <- existing
    }
  }
  index
}

build_topic_rd <- function(topic_key, blocks, param_index = list(), family_index = list(), markdown_default = FALSE) {
  primary <- blocks[[1]]
  sections <- intro_sections(primary)

  use_md <- markdown_default || any(vapply(blocks, function(b) tag_present(b$tags, "md"), logical(1)))
  render_text <- function(x) {
    if (is.null(x)) return(x)
    if (use_md) markdown_to_rd(x) else escape_rd_percent(x)
  }

  title <- sections$title
  if (!nzchar(title)) {
    warning(sprintf("Topic '%s' has no title (first line of the block)", topic_key), call. = FALSE)
    title <- topic_key
  }
  description <- if (nzchar(sections$description)) sections$description else title
  details <- sections$details

  aliases <- character()
  usages <- character()
  arguments <- list()
  examples <- character()
  value_txt <- NULL
  seealso_txt <- NULL
  keywords <- character()

  for (b in blocks) {
    # Use the block's own object name for the \alias{}, not b$name (the
    # shared documentation topic name from @name/@rdname) - otherwise every
    # function grouped under one shared @rdname would alias to the topic
    # name instead of its own name, leaving the actual functions completely
    # undocumented/un-aliased. The "_PACKAGE" sentinel has no real object,
    # so it still falls back to the topic name (e.g. "pkgname-package").
    alias <- if (identical(b$obj_name, "_PACKAGE")) b$name else b$obj_name
    if (!is.null(alias) && !is.na(alias) && nzchar(alias)) {
      aliases <- c(aliases, alias)
    }
    alias_tag <- tag_value(b$tags, "aliases")
    if (!is.null(alias_tag)) {
      aliases <- c(aliases, strsplit(alias_tag, "[ \t]+")[[1]])
    }

    usage_tag <- tag_value(b$tags, "usage")
    if (!is.null(usage_tag)) {
      usages <- c(usages, usage_tag)
    } else if (isTRUE(b$is_function) && !is.na(b$usage)) {
      # Auto-derived usage is built from the function's own formals/
      # defaults (raw R code), not hand-written Rd markup, so a literal
      # "%" in a default value (e.g. width = "100%") must be escaped just
      # like description/details text - otherwise Rd treats the rest of
      # the line as a comment and silently truncates it. An explicit
      # @usage tag (handled above) is left alone since it's the user's own
      # literal Rd markup.
      usages <- c(usages, escape_rd_percent(s3_method_usage(b)))
    }

    for (p in tags_named(b$tags, "param")) {
      parsed <- parse_param_tag(p)
      for (nm in parsed$names) {
        if (is.null(arguments[[nm]])) {
          arguments[[nm]] <- parsed$description
        }
      }
    }

    if (is.null(value_txt)) {
      value_txt <- tag_value(b$tags, "return")
      if (is.null(value_txt)) value_txt <- tag_value(b$tags, "returns")
    }
    if (is.null(seealso_txt)) {
      seealso_txt <- tag_value(b$tags, "seealso")
    }
    kw_tag <- tag_value(b$tags, "keywords")
    if (!is.null(kw_tag)) {
      keywords <- c(keywords, strsplit(kw_tag, "[ \t]+")[[1]])
    }

    ex_tag <- tag_value(b$tags, "examples")
    if (!is.null(ex_tag)) {
      examples <- c(examples, ex_tag)
    }
  }

  aliases <- unique(aliases)
  keywords <- unique(keywords)

  # @inheritParams source: fill in any params not already documented
  # locally from another object's own @param tags. Applied after all local
  # @param tags have been collected, so local docs always take priority.
  for (b in blocks) {
    for (it in tags_named(b$tags, "inheritParams")) {
      val <- str_trim(paste(it$value, collapse = " "))
      for (src in strsplit(val, "[ \t]+")[[1]]) {
        src_name <- sub("^.*::", "", src)
        src_params <- param_index[[src_name]]
        if (is.null(src_params)) next
        for (nm in names(src_params)) {
          if (is.null(arguments[[nm]])) arguments[[nm]] <- src_params[[nm]]
        }
      }
    }
  }

  # Drop any documented argument that isn't an actual formal of one of the
  # functions in this topic. Without this, @inheritParams (which copies
  # every param from the source topic, e.g. a family-grouped @rdname with
  # params only some of its functions use) can leave params in
  # \arguments{} that never appear in \usage{}, which R CMD check flags as
  # "Documented arguments not in \usage". Only applied when the topic has
  # at least one function block to check against, so purely non-function
  # topics (e.g. datasets) are left untouched.
  valid_args <- unique(unlist(lapply(blocks, function(b) b$arg_names)))
  if (length(valid_args) > 0) {
    arguments <- arguments[names(arguments) %in% valid_args]
  }

  # Render seealso_txt (possibly markdown) before appending the @family
  # block below, since that block is already Rd markup and must not be
  # escaped/re-rendered.
  if (!is.null(seealso_txt)) seealso_txt <- render_text(seealso_txt)

  # @family name: add an "Other name: ..." block to \seealso{} linking to
  # every other topic tagged with the same family name. Folded into
  # seealso_txt rather than its own section, same as roxygen2's rendering.
  family_names <- character()
  for (b in blocks) {
    for (t in tags_named(b$tags, "family")) {
      fam <- str_trim(paste(t$value, collapse = " "))
      if (nzchar(fam)) family_names <- c(family_names, fam)
    }
  }
  family_names <- unique(family_names)

  family_lines <- character()
  for (fam in family_names) {
    members <- family_index[[fam]]
    members <- members[members != topic_key]
    if (length(members) == 0) next
    links <- sprintf("\\code{\\link{%s}}", members)
    family_lines <- c(family_lines, sprintf("Other %s: %s", fam, paste(links, collapse = ", ")))
  }

  if (length(family_lines) > 0) {
    family_txt <- paste(family_lines, collapse = "\n\n")
    seealso_txt <- if (is.null(seealso_txt)) family_txt else paste(seealso_txt, family_txt, sep = "\n\n")
  }

  arg_items <- character()
  if (length(arguments) > 0) {
    arg_items <- unlist(lapply(names(arguments), function(nm) {
      c(sprintf("\\item{%s}{%s}", nm, render_text(arguments[[nm]])), "")
    }))
    arg_items <- arg_items[-length(arg_items)] # drop trailing blank
  }

  lines <- c(
    "% Generated by tinyroxygen: do not edit by hand",
    sprintf("%% Please edit documentation in %s", unique(vapply(blocks, function(b) basename(b$file), character(1)))[1]),
    sprintf("\\name{%s}", topic_key),
    sprintf("\\alias{%s}", aliases),
    sprintf("\\title{%s}", render_text(title)),
    if (length(usages) > 0) rd_block("usage", usages),
    if (length(arg_items) > 0) rd_block("arguments", arg_items),
    if (!is.null(value_txt)) rd_block("value", render_text(value_txt)),
    rd_block("description", render_text(description)),
    if (nzchar(details)) rd_block("details", render_text(details)),
    if (!is.null(seealso_txt)) rd_block("seealso", seealso_txt),
    if (length(examples) > 0) rd_block("examples", escape_rd_examples(paste(examples, collapse = "\n\n"))),
    if (length(keywords) > 0) sprintf("\\keyword{%s}", keywords)
  )

  paste(lines, collapse = "\n")
}

# Map family name -> character vector of topic keys tagged with @family
# that name, gathered across every topic. Used to render the "Other
# family: ..." \seealso{} block. Order follows the order topics were
# grouped in (see group_blocks_by_topic).
build_family_index <- function(topics) {
  index <- list()
  for (topic_key in names(topics)) {
    for (b in topics[[topic_key]]) {
      for (t in tags_named(b$tags, "family")) {
        fam <- str_trim(paste(t$value, collapse = " "))
        if (nzchar(fam)) index[[fam]] <- unique(c(index[[fam]], topic_key))
      }
    }
  }
  index
}

rd_roclet_write <- function(pkgdir, topics, param_index = list(), family_index = list()) {
  man_dir <- pkg_man_dir(pkgdir)
  written <- character()
  markdown_default <- pkg_markdown_default(pkgdir)

  for (topic_key in names(topics)) {
    blocks <- topics[[topic_key]]
    if (any(vapply(blocks, function(b) tag_present(b$tags, "noRd"), logical(1)))) {
      next
    }
    rd_text <- build_topic_rd(topic_key, blocks, param_index, family_index, markdown_default)
    rd_path <- file.path(man_dir, paste0(topic_key, ".Rd"))
    writeLines(rd_text, rd_path)
    written <- c(written, basename(rd_path))
  }

  # remove stale generated Rd files that tinyroxygen previously wrote but
  # no longer correspond to a topic
  existing <- list.files(man_dir, pattern = "\\.Rd$", full.names = FALSE)
  for (f in existing) {
    if (f %in% written) next
    first_line <- tryCatch(readLines(file.path(man_dir, f), n = 1, warn = FALSE), error = function(e) "")
    if (length(first_line) && identical(first_line, "% Generated by tinyroxygen: do not edit by hand")) {
      file.remove(file.path(man_dir, f))
    }
  }

  invisible(written)
}
