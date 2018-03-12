#!/bin/bash
# Licensed under the terms of the Apache License, version 2.0.

if [ ! -d "$1" ] || [ ! -e "$1/mission.sqm" ] || [ ! -e "$1/init.sqf" ]
then
    echo "Please specify the mission folder"
    exit 1
fi

MISSION_FOLDER=$(readlink -f "$1")
MISSION_NAME=$(basename "$MISSION_FOLDER")
NEW_MISSION_NAME="$MISSION_NAME.updated"

# Change the working directory to the same as MISSION_FOLDER
cd "$(dirname "$MISSION_FOLDER")"

# Clone lastest FA3
echo "Cloning latest FA3 to $PWD/$NEW_MISSION_NAME"
git clone -q https://github.com/Raptoer/F3.git "$NEW_MISSION_NAME"

echo "Working out mission FA3 version"

# Create a new branch to hold the mission files
command pushd "$NEW_MISSION_NAME" > /dev/null
git checkout -q -b mission
command popd > /dev/null

# Clear out the current files and copy in the mission
rm -r "$NEW_MISSION_NAME"/*
cp -r "$MISSION_FOLDER"/* "$NEW_MISSION_NAME/"

# Commit the mission
command pushd "$NEW_MISSION_NAME" > /dev/null
git add . &> /dev/null
git commit -m "Mission" &> /dev/null

## Find the most likely commit this mission was derived from
# Don't compare ws_fnc to prevent poisoning due to the mission maker updating ws_fnc themselves
FILES_TO_COMPARE=$(find -type f -not -path "*.git/*" -not -path "*ws_fnc/*")
CANDIDATE_COMMITS=$(
    for FILE in $FILES_TO_COMPARE
    do
        REV_COMMITS=$(git rev-list --branches=master master -- $FILE)

        for COMMIT in $REV_COMMITS
        do
                git diff -s --exit-code $COMMIT mission -- $FILE
                if [ $? -eq 0 ]
                then
                        echo $COMMIT
                        break
                fi
        done
    done
)
# Find the most recent candidate commit
LIKELY_COMMIT=$(
    for COMMIT in $CANDIDATE_COMMITS
    do
        echo $(git log -1 --pretty=format:%ct $COMMIT) $COMMIT
    done | sort -nr -k 1 | head -1 | awk '{print $2}'
)

echo "Mission was likely created from $(git describe --all --always $LIKELY_COMMIT) (commit $LIKELY_COMMIT)"
echo "Attempting automatic update"

# Create branch with sensible mission history
git checkout $LIKELY_COMMIT -b updated
command popd > /dev/null
rm -r "$NEW_MISSION_NAME"/*
cp -r "$MISSION_FOLDER"/* "$NEW_MISSION_NAME/"
command pushd "$NEW_MISSION_NAME" > /dev/null
git add . &> /dev/null
git commit -m "Changes" &> /dev/null

# Rebase the branch to update to latest version
git rebase master

# Use mission version of mission.sqm
git checkout --theirs mission.sqm
git add mission.sqm

# Run the mergetool to finish the rebase
git mergetool

echo "The mission has now been updated as much as can be done automatically."
echo "Please run git status to find out which files couldn't be automatically updated, and finish the rebase process after fixing the conflicts"
echo "Remember to delete the .git folder before PBO-ing the updated mission"
