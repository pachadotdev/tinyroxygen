#include <stdlib.h>
#include <assert.h>
#include <stdio.h>
#include "node.h"
#include "houdini.h"
#include "cmark.h"
#include "buffer.h"

/* Compiled code must not call abort()/write to stderr (CRAN policy), so
 * OOM/overflow handlers below call R's own error mechanism instead, which
 * safely unwinds via a longjmp rather than terminating the process. See
 * scripts/cmark.sh. */
extern void Rf_error(const char *, ...) __attribute__((noreturn));

int cmark_version(void) { return CMARK_VERSION; }

const char *cmark_version_string(void) { return CMARK_VERSION_STRING; }

static void *xcalloc(size_t nmem, size_t size) {
  void *ptr = calloc(nmem, size);
  if (!ptr) {
    Rf_error("[cmark] calloc returned null pointer");
  }
  return ptr;
}

static void *xrealloc(void *ptr, size_t size) {
  void *new_ptr = realloc(ptr, size);
  if (!new_ptr) {
    Rf_error("[cmark] realloc returned null pointer");
  }
  return new_ptr;
}

cmark_mem DEFAULT_MEM_ALLOCATOR = {xcalloc, xrealloc, free};

cmark_mem *cmark_get_default_mem_allocator(void) {
  return &DEFAULT_MEM_ALLOCATOR;
}


char *cmark_markdown_to_html(const char *text, size_t len, int options) {
  cmark_node *doc;
  char *result;

  doc = cmark_parse_document(text, len, options);

  result = cmark_render_html(doc, options);
  cmark_node_free(doc);

  return result;
}
