#!/bin/bash
set -euo pipefail

fail() {
    printf 'error: Fleet storyboard metadata: %s\n' "$*" >&2
    exit 1
}

# This script runs in a hosted test target's Xcode build phase. The historical
# production-target argument is accepted for compatibility; TEST_HOST selects it.
for variable in TARGET_BUILD_DIR CONTENTS_FOLDER_PATH TEST_HOST CONFIGURATION_TEMP_DIR; do
    [[ -n "${!variable:-}" ]] || fail "$variable must be set by the hosted test target."
done
[[ "$TARGET_BUILD_DIR" == /* ]] || fail "TARGET_BUILD_DIR must be an absolute path."
[[ "$CONFIGURATION_TEMP_DIR" == /* ]] || fail "CONFIGURATION_TEMP_DIR must be an absolute path."
[[ "$TEST_HOST" == /* && "$TEST_HOST" != */ ]] || fail "TEST_HOST must identify the host application's executable."
case "$CONTENTS_FOLDER_PATH" in
    /*|.|..|./*|../*|*/./*|*/../*|*/.|*/..)
        fail "CONTENTS_FOLDER_PATH must be a relative bundle path without dot components." ;;
esac

host_name="${TEST_HOST##*/}"
source_directory="$CONFIGURATION_TEMP_DIR/$host_name.build"
[[ -d "$source_directory" ]] || fail "Missing host intermediates: $source_directory. Build the host application before this phase."

bundle_directory="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"
destination="$bundle_directory/StoryboardInfo"
[[ ! -L "$destination" ]] || fail "StoryboardInfo must not be a symbolic link: $destination"
[[ ! -e "$destination" || -d "$destination" ]] || fail "StoryboardInfo must be a directory: $destination"
mkdir -p "$bundle_directory"
working_directory=$(mktemp -d "$bundle_directory/.fleet-storyboard-XXXXXX")

cleanup() {
    status=$?
    # Restore the previous output if replacing it failed or was interrupted.
    if [[ -d "$working_directory/previous" && ! -e "$destination" ]]; then
        if ! mv "$working_directory/previous" "$destination"; then
            printf 'error: Fleet storyboard metadata: Restore output from %s/previous\n' "$working_directory" >&2
            return 1
        fi
    fi
    rm -rf "$working_directory"
    return "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# Capture discovery separately so a failed find cannot disappear in a pipeline
# or process substitution. NUL separators preserve every legal filename.
find "$source_directory" -type d -name '*.storyboardc' -print0 > "$working_directory/storyboards"
[[ -s "$working_directory/storyboards" ]] || fail "No compiled storyboards in $source_directory. Remove this phase if the host does not use storyboards."
mkdir "$working_directory/metadata"
while IFS= read -r -d '' storyboard_directory; do
    name="${storyboard_directory##*/}"
    name="${name%.storyboardc}"
    [[ -n "$name" && "$name" != . && "$name" != .. ]] || fail "Invalid storyboard name: $storyboard_directory"
    source_plist="$storyboard_directory/Info.plist"
    [[ -f "$source_plist" && -r "$source_plist" ]] || fail "Missing or unreadable metadata: $source_plist"
    target_directory="$working_directory/metadata/$name"
    if [[ -d "$target_directory" ]]; then
        # Localized copies may share identical compiler metadata. Distinct
        # metadata under the same name cannot be represented by Fleet's layout.
        cmp -s "$source_plist" "$target_directory/Info.plist" || fail "Conflicting storyboard metadata for '$name': $source_plist"
    else
        mkdir "$target_directory"
        cp "$source_plist" "$target_directory/Info.plist"
    fi
done < "$working_directory/storyboards"

# Replace the previous directory only after every discovered plist was copied.
if [[ -d "$destination" ]]; then
    mv "$destination" "$working_directory/previous"
fi
mv "$working_directory/metadata" "$destination"
