#!/bin/sh

COPY_DESTINATION_PATH="$TARGET_BUILD_DIR"/"$CONTENTS_FOLDER_PATH"/StoryboardInfo
if [ -d "$COPY_DESTINATION_PATH" ]; then
rm -rf $COPY_DESTINATION_PATH
fi

mkdir $COPY_DESTINATION_PATH

# Copy all storyboard Info.plist files into the created directory
TEST_HOST_APP_NAME=$(echo "$TEST_HOST" | rev | cut -d '/' -f1 | rev)
TEST_HOST_INTERMEDIATE_BUILD_FOLDER="$CONFIGURATION_TEMP_DIR"/"$TEST_HOST_APP_NAME".build
for storyboardFolder in $(find "$TEST_HOST_INTERMEDIATE_BUILD_FOLDER" -name "*.storyboardc"); do
    STORYBOARD_NAME=$(echo "$storyboardFolder" | rev | cut -d '/' -f1 | rev | cut -d '.' -f1)
    mkdir "$COPY_DESTINATION_PATH"/"$STORYBOARD_NAME"
    cp "$storyboardFolder"/Info.plist "$COPY_DESTINATION_PATH"/"$STORYBOARD_NAME"
done
