package simulator_test

import (
	"simulator"
	"simulator/simulatorfakes"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("EnvironmentParser", func() {
	var (
		fakeSimCtlWrapper *simulatorfakes.FakeSimCtlWrapper
		subject           simulator.EnvironmentParser
	)

	BeforeEach(func() {
		fakeSimCtlWrapper = new(simulatorfakes.FakeSimCtlWrapper)
		fakeSimCtlWrapper.ListReturns(
			[]byte("== Device Types ==\n"+
				"== Runtimes ==\n"+
				"== Devices ==\n"+
				"-- iOS 9.1 --\n"+
				"	iPhone 4s (iPhone-4s-id) (iPhone4s-state)\n"+
				"	iPhone 6 (iPhone-6-id) (iPhone-6-state)\n"+
				"-- iOS 10.0 --\n"+
				"	iPhone 5 (iPhone-5-id) (iPhone5-state)\n"+
				"== Device Pairs =="),
			nil)
		subject = simulator.NewEnvironmentParser(fakeSimCtlWrapper)
	})

	It("returns a description of the sim environment based on use of 'simctl' command line tool", func() {
		environment := subject.ParseEnvironment()
		Expect(environment).ToNot(BeNil())

		nineDotOneDevices := environment.RuntimeToDeviceMap["iOS 9.1"]
		Expect(nineDotOneDevices).To(Equal([]string{"iPhone 4s", "iPhone 6"}))

		tenDevices := environment.RuntimeToDeviceMap["iOS 10.0"]
		Expect(tenDevices).To(Equal([]string{"iPhone 5"}))

		notThereDevices := environment.RuntimeToDeviceMap["iOS 8.0"]
		Expect(notThereDevices).To(BeNil())
	})
})
