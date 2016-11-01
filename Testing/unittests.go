package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"simulator"
	"strings"
)

func main() {
	stdOut := os.Stdout
	stdErr := os.Stderr
	_, err := stdOut.Write([]byte("Running Fleet unit tests...\n"))
	if err != nil {
		log.Fatal(err)
	}

	iosVersion := "iOS 10.0"
	deviceVersion := "iPhone 6"
	availabilityErr := simulator.IsDeviceAvailable(iosVersion, deviceVersion)
	if availabilityErr != nil {
		log.Fatal(availabilityErr)
	}

	iosVersionNumber := strings.Trim(iosVersion, "iOS ")
	destinationString := fmt.Sprintf("platform=iOS Simulator,OS=%s,name=%s", iosVersionNumber, deviceVersion)
	unitTestCommand := exec.Command("xcodebuild", "test", "-workspace", "Fleet.xcworkspace", "-scheme", "Fleet", "-destination", destinationString)
	xcprettyCommand := exec.Command("xcpretty")
	xcprettyCommand.Stdin, err = unitTestCommand.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	xcprettyCommand.Stdout = stdOut
	xcprettyCommand.Stderr = stdErr
	err = xcprettyCommand.Start()
	if err != nil {
		log.Fatal(err)
	}

	err = unitTestCommand.Run()
	if err != nil {
		log.Fatal(err)
	}

	err = xcprettyCommand.Wait()
	if err != nil {
		log.Fatal(err)
	}

	_, err = stdOut.Write([]byte("Fleet unit tests passed...\n"))
	if err != nil {
		log.Fatal(err)
	}
}
