# Work out which object a block documents, without evaluating any code:
# only the parsed language object (call) is inspected. This covers the
# common case of `name <- function(...) ...` and `name <- value`, plus a
# best-effort guess for calls like setClass("Foo", ...).

is_missing_arg <- function(x) {
  is.symbol(x) && identical(as.character(x), "")
}

deparse1 <- function(x) {
  paste(deparse(x, width.cutoff = 500), collapse = " ")
}

object_info <- function(call) {
  no_info <- list(name = NA_character_, is_function = FALSE, usage = NA_character_, arg_names = character())

  # "_PACKAGE" is a bare string literal, not a call: it's Roxygen's
  # sentinel for package-level documentation. Flag it with a dedicated
  # name so collect_blocks() can resolve it to "<pkgname>-package".
  if (is.character(call) && length(call) == 1 && identical(call, "_PACKAGE")) {
    return(list(name = "_PACKAGE", is_function = FALSE, usage = NA_character_, arg_names = character()))
  }

  # Any other bare string literal is Roxygen's convention for documenting
  # a data object that has no assignment expression of its own (e.g. a
  # dataset loaded from data/, documented with a trailing `"objname"`).
  # The string itself is the object's name.
  if (is.character(call) && length(call) == 1) {
    return(list(name = call, is_function = FALSE, usage = NA_character_, arg_names = character()))
  }

  if (!is.call(call)) {
    return(no_info)
  }

  head_sym <- call[[1]]

  if (is.symbol(head_sym) && as.character(head_sym) %in% c("<-", "=", "<<-") && length(call) == 3) {
    lhs <- call[[2]]
    rhs <- call[[3]]
    name <- if (is.symbol(lhs)) {
      as.character(lhs)
    } else if (is.character(lhs) && length(lhs) == 1L) {
      as.character(lhs)
    } else {
      deparse1(lhs)
    }

    if (is.call(rhs) && is.symbol(rhs[[1]]) && identical(as.character(rhs[[1]]), "function")) {
      formals_pl <- rhs[[2]]
      arg_names <- names(formals_pl)
      if (is.null(arg_names)) arg_names <- character(length(formals_pl))
      # Note: never assign formals_pl[[i]] to a bare local variable and
      # then reference it - if the default is missing, R's evaluator
      # treats that variable as an unsupplied argument and throws
      # "argument ... is missing, with no default" on the next reference.
      # Passing the extraction directly as a call argument avoids this.
      arg_strs <- vapply(seq_along(formals_pl), function(i) {
        nm <- arg_names[i]
        if (is_missing_arg(formals_pl[[i]])) {
          nm
        } else {
          paste0(nm, " = ", deparse1(formals_pl[[i]]))
        }
      }, character(1))
      usage <- format_usage(name, arg_strs)
      return(list(name = name, is_function = TRUE, usage = usage, arg_names = arg_names[nzchar(arg_names)]))
    }

    return(list(name = name, is_function = FALSE, usage = name, arg_names = character()))
  }

  # setMethod("generic", "Class", fn): the first argument is the generic
  # name. Using that as the auto-alias causes duplicate \alias{generic}
  # entries across every Rd file that documents a method for the same
  # generic. Return no_info to suppress auto-aliasing; the method-specific
  # alias (e.g. "dbConnect,PqDriver-method") is provided via @aliases tags.
  if (is.symbol(head_sym) && identical(as.character(head_sym), "setMethod")) {
    return(no_info)
  }

  # best-effort: setClass("Foo", ...), setGeneric("foo", ...), etc.
  if (is.symbol(head_sym) && length(call) >= 2 && is.character(call[[2]])) {
    return(list(name = call[[2]], is_function = FALSE, usage = NA_character_, arg_names = character()))
  }

  no_info
}

# Build a \usage{} line for a function call, e.g. "name(x, y = 1)". R CMD
# check's "Rd line widths" check flags \usage lines wider than 90
# characters, so once the one-line form would exceed that, fall back to
# one argument per line (matching the source's own multi-line style):
#   name(
#     x,
#     y = 1
#   )
# The \method{}{} rewrite for S3 methods (see roclet-rd.R's
# s3_method_usage()) only ever replaces the leading "name(" prefix, so it
# works unchanged on either form.
usage_width_limit <- 90

format_r_name <- function(name) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    return(name)
  }
  if (grepl("^[A-Za-z_.][A-Za-z0-9_.]*$", name)) {
    return(name)
  }
  sprintf('"%s"', name)
}

format_usage <- function(name, arg_strs) {
  r_name <- format_r_name(name)
  one_line <- paste0(r_name, "(", paste(arg_strs, collapse = ", "), ")")
  if (length(arg_strs) == 0 || nchar(one_line) <= usage_width_limit) {
    return(one_line)
  }
  paste0(r_name, "(\n  ", paste(arg_strs, collapse = ",\n  "), "\n)")
}

