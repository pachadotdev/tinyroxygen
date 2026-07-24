#!/bin/bash
set -euo pipefail

# Vendors a trimmed-down copy of cmark's core parser + AST API into
# src/cmark/. Only the CommonMark parser and node-tree files are vendored -
# no HTML/XML/LaTeX/man renderers, no GFM extensions, no CLI (main.c). Rd
# rendering is implemented in R (R/markdown.R) by walking the parsed AST.
#
# Usage: scripts/cmark.sh

CMARK_TAG="0.31.2"
CMARK_ARCHIVE_URL="https://github.com/commonmark/cmark/archive/refs/tags/${CMARK_TAG}.tar.gz"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$PKG_DIR/src/cmark"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading cmark @ ${CMARK_TAG} ..."
wget --quiet -O "$TMP_DIR/cmark.tar.gz" "$CMARK_ARCHIVE_URL"
tar -xzf "$TMP_DIR/cmark.tar.gz" -C "$TMP_DIR" --strip-components=1

# Core parser + AST files only (see README for why the rest is excluded).
FILES=(
  blocks.c
  buffer.c buffer.h
  chunk.h
  cmark.c cmark.h
  cmark_ctype.c cmark_ctype.h
  case_fold.inc
  entities.inc
  houdini.h houdini_href_e.c houdini_html_e.c houdini_html_u.c
  inlines.c inlines.h
  iterator.c iterator.h
  node.c node.h
  parser.h
  references.c references.h
  scanners.c scanners.h
  utf8.c utf8.h
)

rm -rf "$DEST"
mkdir -p "$DEST"

for f in "${FILES[@]}"; do
  cp "$TMP_DIR/src/$f" "$DEST/$f"
done

cp "$TMP_DIR/COPYING" "$DEST/COPYING"

# cmark_export.h and cmark_version.h are NOT upstream files - upstream
# generates them via CMake (GenerateExportHeader / configure_file) as part
# of its build. cmark is compiled directly into tinyroxygen's own package
# DLL (no separate library boundary), so no symbol import/export
# decoration is needed. Regenerated here (from CMARK_TAG) so re-vendoring
# stays fully reproducible.
IFS='.' read -r CMARK_MAJOR CMARK_MINOR CMARK_PATCH <<< "$CMARK_TAG"

cat > "$DEST/cmark_export.h" << EOF
/* Not an upstream cmark file - see scripts/cmark.sh. */
#ifndef CMARK_EXPORT_H
#define CMARK_EXPORT_H

#define CMARK_EXPORT
#define CMARK_NO_EXPORT
#define CMARK_DEPRECATED

#endif
EOF

cat > "$DEST/cmark_version.h" << EOF
/* Not an upstream cmark file - see scripts/cmark.sh. */
#ifndef CMARK_VERSION_H
#define CMARK_VERSION_H

#define CMARK_VERSION ((${CMARK_MAJOR} << 16) | (${CMARK_MINOR} << 8) | ${CMARK_PATCH})
#define CMARK_VERSION_STRING "${CMARK_TAG}"

#endif
EOF

echo "Vendored ${#FILES[@]} files from cmark ${CMARK_TAG} into ${DEST#$PKG_DIR/}"

# =======================
# ==== CRAN PATCHES =====
# =======================

# CRAN policy forbids compiled code calling abort() or writing to
# stderr/stdout. Upstream cmark's OOM/overflow handlers do both (cmark.c's
# xcalloc/xrealloc, buffer.c's cmark_strbuf_grow) - patch them to call R's
# own Rf_error() instead, which safely unwinds via a longjmp. Also fixes a
# -Wdiscarded-qualifiers warning in utf8.c (bsearch() into a const table
# assigned to a non-const pointer).

perl -0777 -pi -e '
  s/#include "buffer\.h"\n\n/#include "buffer.h"\n\n\/* Compiled code must not call abort()\/write to stderr (CRAN policy), so\n * OOM\/overflow handlers below call R'"'"'s own error mechanism instead, which\n * safely unwinds via a longjmp rather than terminating the process. See\n * scripts\/cmark.sh. *\/\nextern void Rf_error(const char *, ...) __attribute__((noreturn));\n\n/;
  s/fprintf\(stderr, "\[cmark\] calloc returned null pointer, aborting\\n"\);\n    abort\(\);/Rf_error("[cmark] calloc returned null pointer");/;
  s/fprintf\(stderr, "\[cmark\] realloc returned null pointer, aborting\\n"\);\n    abort\(\);/Rf_error("[cmark] realloc returned null pointer");/;
' "$DEST/cmark.c"

perl -0777 -pi -e '
  s/#include "buffer\.h"\n\n\/\* Used as default/#include "buffer.h"\n\n\/* Compiled code must not call abort()\/write to stderr (CRAN policy), so\n * the overflow handler below calls R'"'"'s own error mechanism instead. See\n * scripts\/cmark.sh. *\/\nextern void Rf_error(const char *, ...) __attribute__((noreturn));\n\n\/* Used as default/;
  s/fprintf\(stderr,\n      "\[cmark\] cmark_strbuf_grow requests buffer with size > %d, aborting\\n",\n         \(INT32_MAX \/ 2\)\);\n    abort\(\);/Rf_error("[cmark] cmark_strbuf_grow requests buffer with size > %d",\n             (INT32_MAX \/ 2));/;
' "$DEST/buffer.c"

sed -i \
  -e 's/uint32_t \*entry = bsearch(&key, cf_table,/const uint32_t *entry = bsearch(\&key, cf_table,/' \
  "$DEST/utf8.c"

echo "Patched cmark.c, buffer.c, utf8.c for CRAN compiled-code policy"
