package main

import (
	"io"
	"log"
	"os"
	"os/exec"
)

func main() {
	stdOut := os.Stdout
	stdErr := os.Stderr

	runUnitTests(stdOut, stdErr)
}

func runUnitTests(stdOut io.Writer, stdErr io.Writer) {
	runCommand := exec.Command("go", "run", "script/unittests.go")
	runCommand.Stdout = stdOut
	runCommand.Stderr = stdErr

	runErr := runCommand.Run()
	if runErr != nil {
		log.Fatal(runErr)
	}
}
