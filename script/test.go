package main

import (
	"log"
	"os"
	"os/exec"
)

func main() {
	stdOut := os.Stdout
	stdErr := os.Stderr
	_, err := stdOut.Write([]byte("Running tests...\n"))
	if err != nil {
		log.Fatal(err)
	}

	testCommand := exec.Command("xcodebuild", "test", "-workspace", "Fleet.xcworkspace", "-scheme", "FleetTests", "-destination", "platform=iOS Simulator,OS=9.3,name=iPhone 6")
	testCommand.Stdout = stdOut
	testCommand.Stderr = stdErr
	testErr := testCommand.Run()
	if testErr != nil {
		log.Fatal(testErr)
	}
}
