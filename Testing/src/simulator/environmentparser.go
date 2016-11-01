package simulator

import (
	"bufio"
	"bytes"
	"log"
	"strings"
)

type EnvironmentParser interface {
	ParseEnvironment() *SimulatorEnvironment
}

func NewEnvironmentParser(simCtlWrapper SimCtlWrapper) EnvironmentParser {
	return &environmentParser{
		simCtlWrapper: simCtlWrapper,
	}
}

type environmentParser struct {
	simCtlWrapper SimCtlWrapper
}

func (p *environmentParser) ParseEnvironment() *SimulatorEnvironment {
	environment := &SimulatorEnvironment{
		RuntimeToDeviceMap: make(map[string][]string),
	}
	infoBytes, err := p.simCtlWrapper.List()

	if err != nil {
		log.Fatal(err)
	}

	infoBuffer := bytes.NewBuffer(infoBytes)
	infoScanner := bufio.NewScanner(infoBuffer)
	for infoScanner.Scan() {
		if infoScanner.Text() == "== Devices ==" {
			for infoScanner.Text() != "== Device Pairs ==" {
				if strings.HasPrefix(infoScanner.Text(), "--") {
					runtimeString := strings.Trim(infoScanner.Text(), "-\n \t\r")
					devices := []string{}
					infoScanner.Scan()
					hasMoreDevices := !strings.HasPrefix(infoScanner.Text(), "--")
					for hasMoreDevices {
						substrings := strings.SplitN(infoScanner.Text(), "(", 2)
						deviceString := strings.Trim(substrings[0], " \n\t\r")
						devices = append(devices, deviceString)
						infoScanner.Scan()
						hasMoreDevices = !strings.HasPrefix(infoScanner.Text(), "--") && infoScanner.Text() != "== Device Pairs =="

					}

					environment.RuntimeToDeviceMap[runtimeString] = devices
				} else {
					infoScanner.Scan()
				}
			}
		}
	}

	return environment
}
