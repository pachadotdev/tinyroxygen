/* R <-> cmark marshalling. Parses Markdown text with cmark and returns the
 * resulting AST as a plain nested R list, so all Rd-rendering logic can
 * live in pure R (see R/markdown.R). Uses only the base R C API
 * (Rinternals.h / R_ext/Rdynload.h) - no Rcpp/cpp11/cpp4r.
 */
#include <string.h>
#include <R.h>
#include <Rinternals.h>
#include "cmark/cmark.h"

static SEXP mkStringOrNA(const char *s) {
  if (s == NULL) return Rf_ScalarString(NA_STRING);
  return Rf_mkString(s);
}

static SEXP node_to_r(cmark_node *node) {
  int n_children = 0;
  for (cmark_node *child = cmark_node_first_child(node); child != NULL;
       child = cmark_node_next(child)) {
    n_children++;
  }

  SEXP children = PROTECT(Rf_allocVector(VECSXP, n_children));
  int i = 0;
  for (cmark_node *child = cmark_node_first_child(node); child != NULL;
       child = cmark_node_next(child)) {
    SET_VECTOR_ELT(children, i++, node_to_r(child));
  }

  const char *type = cmark_node_get_type_string(node);
  const char *literal = cmark_node_get_literal(node);
  const char *url = cmark_node_get_url(node);
  cmark_list_type list_type = cmark_node_get_list_type(node);
  int heading_level = cmark_node_get_heading_level(node);

  const char *names[] = {"type", "literal", "url", "list_type", "level", "children", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));

  SET_VECTOR_ELT(out, 0, mkStringOrNA(type));
  SET_VECTOR_ELT(out, 1, mkStringOrNA(literal));
  SET_VECTOR_ELT(out, 2, mkStringOrNA(url));
  SET_VECTOR_ELT(
      out, 3,
      mkStringOrNA(list_type == CMARK_ORDERED_LIST ? "ordered"
                    : list_type == CMARK_BULLET_LIST ? "bullet"
                                                      : NULL));
  SET_VECTOR_ELT(out, 4, Rf_ScalarInteger(heading_level));
  SET_VECTOR_ELT(out, 5, children);

  UNPROTECT(2); /* children, out */
  return out;
}

SEXP R_parse_markdown(SEXP text) {
  if (TYPEOF(text) != STRSXP || Rf_length(text) != 1) {
    Rf_error("'text' must be a single string");
  }
  if (STRING_ELT(text, 0) == NA_STRING) {
    Rf_error("'text' must not be NA");
  }

  const char *buf = Rf_translateCharUTF8(STRING_ELT(text, 0));
  cmark_node *root = cmark_parse_document(buf, strlen(buf), CMARK_OPT_DEFAULT);
  if (root == NULL) {
    Rf_error("failed to parse markdown text");
  }

  SEXP out = PROTECT(node_to_r(root));
  cmark_node_free(root);
  UNPROTECT(1);
  return out;
}
