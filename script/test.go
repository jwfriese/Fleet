package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/jwfriese/iossimulator"
)

func main() {
	runTestsForiOS()
	runTestsFortvOS()
}

func runTestsForiOS() {
	iOSConfig := &testConfig{
		os:         "iOS",
		osVersion:  "10.1",
		device:     "iPhone 7",
		schemeName: "Fleet",
	}

	runFor(iOSConfig)
}

func runTestsFortvOS() {
	tvOSConfig := &testConfig{
		os:         "tvOS",
		osVersion:  "10.2",
		device:     "Apple TV 1080p",
		schemeName: "Fleet-tvOS",
	}

	runFor(tvOSConfig)
}

type testConfig struct {
	os         string
	osVersion  string
	device     string
	schemeName string
}

func runFor(config *testConfig) {
	testInitReport := fmt.Sprintf("Running Fleet unit tests with %s version '%s' on device type '%s'\n", config.os, config.osVersion, config.device)
	_, err := os.Stdout.Write([]byte(testInitReport))
	if err != nil {
		log.Fatal(err)
	}

	if config.os == "iOS" {
		iosVersion := fmt.Sprintf("iOS %s", config.osVersion)
		availabilityErr := iossimulator.IsDeviceAvailable(iosVersion, config.device)
		if availabilityErr != nil {
			log.Fatal(availabilityErr)
		}
	}

	destinationString := fmt.Sprintf("platform=%s Simulator,OS=%s,name=%s", config.os, config.osVersion, config.device)
	unitTestCommand := exec.Command("xcodebuild", "test", "-workspace", "Fleet.xcworkspace", "-scheme", config.schemeName, "-destination", destinationString)
	xcprettyCommand := exec.Command("xcpretty")
	xcprettyCommand.Stdin, err = unitTestCommand.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	xcprettyCommand.Stdout = os.Stdout
	xcprettyCommand.Stderr = os.Stderr
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

	_, err = os.Stdout.Write([]byte("Fleet unit tests passed...\n"))
	if err != nil {
		log.Fatal(err)
	}
}
