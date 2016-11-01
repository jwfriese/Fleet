package simulator

import (
	"errors"
	"fmt"
)

func IsDeviceAvailable(osString string, deviceTypeString string) error {
	simCtlWrapper := NewSimCtlWrapper()
	environmentParser := NewEnvironmentParser(simCtlWrapper)
	availability := NewSimulatorAvailability(environmentParser)
	return availability.CheckAvailability(osString, deviceTypeString)
}

type SimulatorAvailability interface {
	CheckAvailability(string, string) error
}

func NewSimulatorAvailability(environmentParser EnvironmentParser) SimulatorAvailability {
	return &simulatorAvailability{
		environmentParser: environmentParser,
	}
}

type simulatorAvailability struct {
	environmentParser EnvironmentParser
}

func (a *simulatorAvailability) CheckAvailability(osString string, deviceTypeString string) error {
	environment := a.environmentParser.ParseEnvironment()
	devices := environment.RuntimeToDeviceMap[osString]
	if len(devices) == 0 {
		errorString := fmt.Sprintf("Could not find '%s' runtime", osString)
		return errors.New(errorString)
	}

	for _, device := range devices {
		if device == deviceTypeString {
			return nil
		}
	}

	errorString := fmt.Sprintf("Could not find '%s' device for '%s' runtime", deviceTypeString, osString)
	return errors.New(errorString)
}
