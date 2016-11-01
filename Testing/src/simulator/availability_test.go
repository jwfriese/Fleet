package simulator_test

import (
	"simulator"
	"simulator/simulatorfakes"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Simulator Availability", func() {
	var (
		fakeEnvironmentParser *simulatorfakes.FakeEnvironmentParser
		subject               simulator.SimulatorAvailability
	)

	BeforeEach(func() {
		fakeEnvironmentParser = new(simulatorfakes.FakeEnvironmentParser)
		subject = simulator.NewSimulatorAvailability(fakeEnvironmentParser)
	})

	Describe("CheckAvailability", func() {
		BeforeEach(func() {
			environment := &simulator.SimulatorEnvironment{
				RuntimeToDeviceMap: map[string][]string{
					"iOS 9.0":  []string{"iPhone 4s", "iPhone 6"},
					"iOS 10.0": []string{"iPhone 5", "iPhone 7"},
				},
			}

			fakeEnvironmentParser.ParseEnvironmentReturns(environment)
		})

		Describe("When the given device is available for the given runtime", func() {
			It("returns no error", func() {
				err := subject.CheckAvailability("iOS 9.0", "iPhone 6")
				Expect(err).ToNot(HaveOccurred())
			})
		})

		Describe("When the given device is not available for the given runtime", func() {
			It("returns a descriptive error", func() {
				err := subject.CheckAvailability("iOS 9.0", "iPhone 5")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Could not find 'iPhone 5' device for 'iOS 9.0' runtime"))
			})
		})

		Describe("When the given runtime is not available", func() {
			It("returns a descriptive error", func() {
				err := subject.CheckAvailability("iOS 9.1", "iPhone 4s")
				Expect(err).To(HaveOccurred())
			})
		})
	})
})
