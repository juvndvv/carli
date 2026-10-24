#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "usage: $0 <file> <KEY> <value>" >&2
    exit 64
fi

file="$1"
key="$2"
value="$3"
tmp="$(mktemp "${file}.XXXXXX")"

awk -v key="$key" -v value="$value" '
    BEGIN { written = 0 }
    index($0, key "=") == 1 { print key "=" value; written = 1; next }
    { print }
    END { if (!written) print key "=" value }
' "$file" > "$tmp"

cat "$tmp" > "$file"
rm -f "$tmp"
