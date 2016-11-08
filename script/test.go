package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/jwfriese/iossimulator"
)

func main() {
	stdOut := os.Stdout
	stdErr := os.Stderr
	programCall := os.Args
	if len(programCall) < 3 {
		log.Fatal(errors.New("Usage: ./test <runtime> <device type>"))
	}

	args := programCall[1:]
	iosVersion := args[0]
	deviceVersion := args[1]

	testInitReport := fmt.Sprintf("Running Fleet unit tests with iOS version '%s' on  device type '%s'\n", iosVersion, deviceVersion)
	_, err := stdOut.Write([]byte(testInitReport))
	if err != nil {
		log.Fatal(err)
	}

	availabilityErr := iossimulator.IsDeviceAvailable(iosVersion, deviceVersion)
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
