#!/bin/bash
set -euo pipefail

# Locate the resource by its filename rather than SwiftPM's implementation-
# defined bundle name. Search only top-level product resource bundles.
manifest=$(mktemp "$TEMP_DIR/fleet-metadata-scripts-XXXXXX")
trap 'rm -f "$manifest"' EXIT
find "$BUILT_PRODUCTS_DIR" -maxdepth 2 -type f -name copy_storyboard_info_files.sh -print0 > "$manifest"
script_path=
while IFS= read -r -d '' candidate; do
    [[ "$candidate" == *.bundle/* ]] || continue
    if [[ -n "$script_path" ]]; then
        printf 'error: Multiple Fleet metadata scripts in %s\n' "$BUILT_PRODUCTS_DIR" >&2
        exit 1
    fi
    script_path="$candidate"
done < "$manifest"
if [[ -z "$script_path" ]]; then
    printf 'error: Fleet SwiftPM metadata script resource missing in %s\n' "$BUILT_PRODUCTS_DIR" >&2
    exit 1
fi
/bin/bash "$script_path"
