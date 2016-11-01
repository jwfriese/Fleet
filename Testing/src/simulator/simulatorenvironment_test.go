package simulator_test

import (
	. "simulator"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("SimulatorEnvironment", func() {
	Describe("AvailableRuntimes()", func() {
		It("returns the available runtimes", func() {
			simEnv := &SimulatorEnvironment{
				RuntimeToDeviceMap: make(map[string][]string),
			}
			simEnv.RuntimeToDeviceMap["runtime 1"] = []string{}
			simEnv.RuntimeToDeviceMap["runtime 2"] = []string{}
			simEnv.RuntimeToDeviceMap["runtime 3"] = []string{}

			runtimes := simEnv.AvailableRuntimes()
			Expect(len(runtimes)).To(BeEquivalentTo(3))
			Expect(runtimes).To(ContainElement("runtime 1"))
			Expect(runtimes).To(ContainElement("runtime 2"))
			Expect(runtimes).To(ContainElement("runtime 3"))
		})
	})
})
