package main

import (
	"log"
	"os"
	"os/exec"
)

func main() {
	stdOut := os.Stdout
	stdErr := os.Stderr
	_, err := stdOut.Write([]byte("Running Fleet unit tests...\n"))
	if err != nil {
		log.Fatal(err)
	}

	unitTestCommand := exec.Command("xcodebuild", "test", "-workspace", "Fleet.xcworkspace", "-scheme", "FleetTests", "-destination", "platform=iOS Simulator,OS=9.3,name=iPhone 6")
	unitTestCommand.Stdout = stdOut
	unitTestCommand.Stderr = stdErr
	unitTestErr := unitTestCommand.Run()
	if unitTestErr != nil {
		log.Fatal(unitTestErr)
	}

	_, err = stdOut.Write([]byte("Fleet unit tests passed...\n"))
	if err != nil {
		log.Fatal(err)
	}
}
