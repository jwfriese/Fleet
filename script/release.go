package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/fatih/color"
)

type SemanticVersion struct {
	major int
	minor int
	patch int
}

func (v *SemanticVersion) compare(other *SemanticVersion) int {
	if v.major != other.major {
		return compare(v.major, other.major)
	}
	if v.minor != other.minor {
		return compare(v.minor, other.minor)
	}
	if v.patch != other.patch {
		return compare(v.patch, other.patch)
	}

	return 0
}

func compare(lhs int, rhs int) int {
	if lhs == rhs {
		return 0
	} else if lhs < rhs {
		return -1
	}

	return 1
}

func printInfo(str string) {
	color.Yellow(str)
}

func printYay(str string) {
	color.Green(str)
	fmt.Println("")
}

func printError(err error) {
	message := fmt.Sprintf("Error: %s", err.Error())
	color.Red(message)
}

func main() {
	programCall := os.Args
	if len(programCall) < 2 {
		log.Fatal(errors.New("Usage: ./release <new-version>"))
	}

	args := programCall[1:]
	newVersion := args[0]
	printInfo("Fetching current version string...")
	currentVersion, fetchCurrentErr := fetchCurrentVersionString()
	if fetchCurrentErr != nil {
		printError(fetchCurrentErr)
		return
	}
	foundCurrentVersion := fmt.Sprintf("Found current version: %s", currentVersion)
	printYay(foundCurrentVersion)

	printInfo("Verifying new version is greater than current version...")
	if isNewVersionErr := verifyNewerThanCurrentVersion(newVersion, currentVersion); isNewVersionErr != nil {
		printError(isNewVersionErr)
		return
	}
	confirmIsNewVersionMessage := fmt.Sprintf("Confirmed: %s > %s", newVersion, currentVersion)
	printYay(confirmIsNewVersionMessage)

	bumpingVersionMessage := fmt.Sprintf("Bumping Fleet version to %s", newVersion)
	printInfo(bumpingVersionMessage)
	if bumpVersionErr := bumpVersionTo(newVersion, currentVersion); bumpVersionErr != nil {
		printError(bumpVersionErr)
		return
	}
	didBumpVersionMessage := fmt.Sprintf("Finished setting Fleet version to %s", newVersion)
	printYay(didBumpVersionMessage)

	printInfo("Committing new release...")
	if commitErr := commitRelease(newVersion); commitErr != nil {
		printError(commitErr)
		return
	}
	printYay("Committed")

	printInfo("Pushing new release to Github...")
	if pushErr := pushRelease(); pushErr != nil {
		printError(pushErr)
		return
	}
	printYay("Pushed")

	printInfo("Tagging new release and pushing tags...")
	if tagErr := tagRelease(newVersion); tagErr != nil {
		printError(tagErr)
		return
	}
	tagMessage := fmt.Sprintf("Created and pushed tag %s", newVersion)
	printYay(tagMessage)

	printInfo("Updating Cocoapod...")
	if podPushErr := updateCocoapod(); podPushErr != nil {
		printError(podPushErr)
		return
	}
	updatedPodMessage := fmt.Sprintf("Cocoapod updated to version %s", newVersion)
	printYay(updatedPodMessage)

	successMessage := fmt.Sprintf("Finished successfully updating Fleet to version %s", newVersion)
	printYay(successMessage)
}

func verifyNewerThanCurrentVersion(newVersionString string, currentVersionString string) error {
	newVersion, err := convertToSemanticVersion(newVersionString)
	if err != nil {
		return err
	}

	currentVersion, err := convertToSemanticVersion(currentVersionString)
	if err != nil {
		return err
	}

	compareResult := newVersion.compare(currentVersion)
	if compareResult != 1 {
		message := fmt.Sprintf("'%s' is not a greater semantic version than '%v.%v.%v'.", newVersionString, currentVersion.major, currentVersion.minor, currentVersion.patch)
		return errors.New(message)
	}

	return nil
}

func fetchCurrentVersionString() (string, error) {
	versionToolOutput, err := exec.Command("agvtool", "vers").Output()
	if err != nil {
		return "", err
	}

	reader := bytes.NewBuffer(versionToolOutput)
	bufReader := bufio.NewReader(reader)

	_, firstLineErr := bufReader.ReadString('\n')
	if firstLineErr != nil {
		return "", firstLineErr
	}

	lineWithVersion, versionLineErr := bufReader.ReadString('\n')
	if versionLineErr != nil {
		return "", versionLineErr
	}

	strippedVersion := strings.Trim(lineWithVersion, " \n\t\r")
	return strippedVersion, nil
}

func convertToSemanticVersion(str string) (*SemanticVersion, error) {
	if strings.ContainsAny(str, " \n\t\r") {
		message := fmt.Sprintf("'%s' not a semantic verison: Semantic versions cannot contain whitespace.", str)
		return nil, errors.New(message)
	}

	components := strings.Split(str, ".")
	if len(components) != 3 {
		message := fmt.Sprintf("'%s' not a semantic verison: Semantic versions have 3 dot-separated components.", str)
		return nil, errors.New(message)
	}

	major, conversionErr := strconv.Atoi(components[0])
	if conversionErr != nil {
		message := fmt.Sprintf("'%s' not a semantic verison: Each dot-separated component must be an integer.", str)
		return nil, errors.New(message)
	}

	minor, conversionErr := strconv.Atoi(components[1])
	if conversionErr != nil {
		message := fmt.Sprintf("'%s' not a semantic verison: Each dot-separated component must be an integer.", str)
		return nil, errors.New(message)
	}

	patch, conversionErr := strconv.Atoi(components[2])
	if conversionErr != nil {
		message := fmt.Sprintf("'%s' not a semantic verison: Each dot-separated component must be an integer.", str)
		return nil, errors.New(message)
	}

	return &SemanticVersion{
		major: major,
		minor: minor,
		patch: patch,
	}, nil
}

func bumpVersionTo(newVersion string, currentVersion string) error {
	agvToolErr := agvBumpVersion(newVersion)
	if agvToolErr != nil {
		return agvToolErr
	}

	infoPlistErr := bumpInfoPlistVersion(newVersion)
	if infoPlistErr != nil {
		return infoPlistErr
	}

	podspecErr := bumpPodspec(newVersion, currentVersion)
	if podspecErr != nil {
		return podspecErr
	}

	return nil
}

func agvBumpVersion(newVersion string) error {
	_, err := exec.Command("agvtool", "new-version", newVersion).Output()
	return err
}

func bumpInfoPlistVersion(newVersion string) error {
	_, err := exec.Command("plutil", "-replace", "CFBundleShortVersionString", "-string", newVersion, "Fleet/Info.plist").Output()
	return err
}

func bumpPodspec(newVersion string, currentVersion string) error {
	fileBytes, readErr := ioutil.ReadFile("Fleet.podspec")
	if readErr != nil {
		return readErr
	}

	fileString := string(fileBytes)
	newFileString := strings.Replace(fileString, currentVersion, newVersion, -1)
	writeErr := ioutil.WriteFile("Fleet.podspec", []byte(newFileString), 0644)
	if writeErr != nil {
		return writeErr
	}

	return nil
}

func commitRelease(newVersion string) error {
	if addProjectErr := addToCommit("Fleet.xcodeproj/"); addProjectErr != nil {
		return addProjectErr
	}
	if addInfoPlistErr := addToCommit("Fleet/Info.plist"); addInfoPlistErr != nil {
		return addInfoPlistErr
	}
	if addPodspecErr := addToCommit("Fleet.podspec"); addPodspecErr != nil {
		return addPodspecErr
	}

	releaseCommitMessage := fmt.Sprintf("Bump version to %s", newVersion)
	_, commitErr := exec.Command("git", "commit", "-m", releaseCommitMessage).Output()
	return commitErr
}

func addToCommit(fileName string) error {
	_, err := exec.Command("git", "add", fileName).Output()
	return err
}

func pushRelease() error {
	_, err := exec.Command("git", "push", "origin", "head").Output()
	return err
}

func tagRelease(newVersion string) error {
	_, tagErr := exec.Command("git", "tag", newVersion).Output()
	if tagErr != nil {
		return tagErr
	}

	_, pushErr := exec.Command("git", "push", "--tags").Output()
	return pushErr
}

func updateCocoapod() error {
	_, err := exec.Command("pod", "trunk", "push", "Fleet.podspec").Output()
	return err
}
