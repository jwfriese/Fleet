package simulator

import (
	"os/exec"
)

type SimCtlWrapper interface {
	List() ([]byte, error)
}

func NewSimCtlWrapper() SimCtlWrapper {
	return &simCtlWrapper{}
}

type simCtlWrapper struct{}

func (w *simCtlWrapper) List() ([]byte, error) {
	getInfoCommand := exec.Command("xcrun", "simctl", "list")
	return getInfoCommand.Output()
}
