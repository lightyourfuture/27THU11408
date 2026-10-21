#!/usr/bin/env bash
# 预览：把 PDF 渲染成 PNG 到指定目录
out="${2:?}"; mkdir -p "$out"; find "$out" -name 'p-*.png' -delete; pdftoppm -r "${3:-70}" -png "$1" "$out/p"
