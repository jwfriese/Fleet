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

	unitTestCommand := exec.Command("xcodebuild", "test", "-workspace", "Fleet.xcworkspace", "-scheme", "Fleet", "-destination", "platform=iOS Simulator,OS=9.3,name=iPhone 6")
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
