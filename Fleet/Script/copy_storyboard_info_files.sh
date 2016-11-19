#!/bin/sh

COPY_DESTINATION_PATH="$TARGET_BUILD_DIR"/"$CONTENTS_FOLDER_PATH"/StoryboardInfo
if [ -d "$COPY_DESTINATION_PATH" ]; then
    rm -rf $COPY_DESTINATION_PATH
fi

mkdir -p "$COPY_DESTINATION_PATH"

# Copy all storyboard Info.plist files into the created directory
TEST_HOST_APP_NAME=$(echo "$TEST_HOST" | rev | cut -d '/' -f1 | rev)
TEST_HOST_INTERMEDIATE_BUILD_FOLDER="$CONFIGURATION_TEMP_DIR"/"$TEST_HOST_APP_NAME".build

find "$TEST_HOST_INTERMEDIATE_BUILD_FOLDER" -name "*.storyboardc"|while read STORYBOARD_FOLDER; do
    STORYBOARD_NAME=$(echo "$STORYBOARD_FOLDER" | rev | cut -d '/' -f1 | rev | cut -d '.' -f1)
    mkdir -p "$COPY_DESTINATION_PATH"/"$STORYBOARD_NAME"
    cp "$STORYBOARD_FOLDER"/Info.plist "$COPY_DESTINATION_PATH"/"$STORYBOARD_NAME"
done
