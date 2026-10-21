#!/usr/bin/env bash
# 用法：bash _build/build.sh "源码/第1章 绪论/1.1 数据结构的基本概念.md" [更多 .md ...]
# 输出：PDF 放到 正课笔记/<章>/ 或 课后习题/<章>/（文件名含"课后习题"的归后者）；LaTeX 源码 .tex 留在 .md 旁边
# 冻结：_build/frozen.txt 里的笔记拒绝编译，除非 ALLOW_FROZEN=1
# 依赖：pandoc ≥3.1、xelatex（texlive-xetex + texlive-lang-chinese）、Noto CJK 字体、mermaid-cli(mmdc)
set -euo pipefail
export LANG=C.UTF-8 LC_ALL=C.UTF-8
BUILD="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$BUILD")"
export NOTES_BUILD="$BUILD"
export MMDC="${MMDC:-mmdc}"
mkdir -p "$BUILD/cache"
for md in "$@"; do
  src="$(cd "$(dirname "$md")" && pwd)/$(basename "$md")"
  rel="${src#"$ROOT"/}"
  if grep -qxF "$rel" "$BUILD/frozen.txt" 2>/dev/null && [ "${ALLOW_FROZEN:-0}" != 1 ]; then
    echo "拒绝：$rel 已冻结（见 _build/frozen.txt）。Curran 明确要求修改时才用 ALLOW_FROZEN=1 放行。" >&2
    exit 3
  fi
  dir="$(dirname "$src")"; name="$(basename "$src" .md)"
  tmp="$(mktemp -d)"
  ( cd "$dir"
    pandoc "$src" -f markdown+fenced_divs+bracketed_spans+pipe_tables+tex_math_dollars \
      --template "$BUILD/cornell.latex" --lua-filter "$BUILD/cornell.lua" \
      --highlight-style "$BUILD/wd-code.theme" -o "$tmp/note.tex"
    xelatex -interaction=nonstopmode -halt-on-error -output-directory "$tmp" "$tmp/note.tex" >"$tmp/log1" 2>&1 || { tail -40 "$tmp/note.log"; exit 1; }
    xelatex -interaction=nonstopmode -halt-on-error -output-directory "$tmp" "$tmp/note.tex" >"$tmp/log2" 2>&1 || { tail -40 "$tmp/note.log"; exit 1; }
  )
  chap="$(basename "$dir")"
  case "$name" in *课后习题*) kind="课后习题" ;; *) kind="正课笔记" ;; esac
  mkdir -p "$ROOT/$kind/$chap"
  cp "$tmp/note.pdf" "$ROOT/$kind/$chap/$name.pdf"
  cp "$tmp/note.tex" "$dir/$name.tex"
  grep -E "Overfull|LaTeX Warning: (Reference|Marginpar)" "$tmp/note.log" | head -5 || true
  echo "OK -> $kind/$chap/$name.pdf"
  rm -rf "$tmp"
done
