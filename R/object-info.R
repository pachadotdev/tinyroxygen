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
  no_info <- list(name = NA_character_, is_function = FALSE, usage = NA_character_)

  if (!is.call(call)) {
    return(no_info)
  }

  head_sym <- call[[1]]

  if (is.symbol(head_sym) && as.character(head_sym) %in% c("<-", "=", "<<-") && length(call) == 3) {
    lhs <- call[[2]]
    rhs <- call[[3]]
    name <- if (is.symbol(lhs)) as.character(lhs) else deparse1(lhs)

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
      usage <- paste0(name, "(", paste(arg_strs, collapse = ", "), ")")
      return(list(name = name, is_function = TRUE, usage = usage))
    }

    return(list(name = name, is_function = FALSE, usage = name))
  }

  # best-effort: setClass("Foo", ...), setGeneric("foo", ...), etc.
  if (is.symbol(head_sym) && length(call) >= 2 && is.character(call[[2]])) {
    return(list(name = call[[2]], is_function = FALSE, usage = NA_character_))
  }

  no_info
}
