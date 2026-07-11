#!/bin/sh
# Post-docs-build check: every Mermaid fence in the docs source must have produced a
# rendered node in the built HTML (fence count == node count).
#
# The incident this catches: a Sphinx -W pipeline with no Mermaid extension silently
# shipped a fresh doc's diagram as a fenced code block — the docs-as-deliverable
# anti-pattern — because nothing verified the renderer was provisioned and actually
# fired. The build alone can't catch it: an unrendered fence is just a code block,
# not a warning.
#
# Runs from the repo root AFTER a docs build (wire it into your docs target, which CI
# reuses). Fail-closed: a missing build directory is a FAIL, not a skip.
#
# Defaults fit Sphinx + MyST + sphinxcontrib-mermaid; override per pipeline:
#   DIAGRAMS_SRC_DIR   docs source tree scanned for fences    (default: docs/source)
#   DIAGRAMS_OUT_DIR   built HTML tree scanned for nodes      (default: docs/build/html)
#   DIAGRAMS_FENCE     literal fence opener to count          (default: ```{mermaid})
#   DIAGRAMS_NODE      literal rendered-node marker to count  (default: class="mermaid")
set -u

default_fence='```{mermaid}'
default_node='class="mermaid"'
SRC="${DIAGRAMS_SRC_DIR:-docs/source}"
OUT="${DIAGRAMS_OUT_DIR:-docs/build/html}"
FENCE="${DIAGRAMS_FENCE:-$default_fence}"
NODE="${DIAGRAMS_NODE:-$default_node}"

[ -d "$OUT" ] || {
  echo "FAIL: $OUT not found — run the docs build first (this check verifies its output)."
  exit 1
}

fences=$(grep -rF "$FENCE" "$SRC" --include='*.md' | wc -l | tr -d ' ')
nodes=$(grep -roF "$NODE" "$OUT" | wc -l | tr -d ' ')

if [ "$fences" -eq 0 ]; then
  echo "ok: no mermaid fences in $SRC — nothing to verify"
  exit 0
fi

if [ "$fences" -ne "$nodes" ]; then
  echo "FAIL: $fences mermaid fence(s) in $SRC but $nodes rendered node(s) in $OUT."
  echo "  A fence that didn't render ships as a dead code block — the renderer is"
  echo "  missing or not firing (Sphinx: sphinxcontrib.mermaid must be in conf.py"
  echo "  extensions and in the docs dependency group)."
  exit 1
fi

echo "ok: $fences/$fences mermaid fences rendered"
