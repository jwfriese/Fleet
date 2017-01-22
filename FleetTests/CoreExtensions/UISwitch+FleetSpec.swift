import XCTest
import Fleet
import Nimble

class UISwitch_FleetSpec: XCTestCase {
    func test_flip_whenSwitchIsVisibleAndEnabled_togglesTheValueOfTheSwitch() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = true
        expect(subject.isOn).to(beFalse())

        var error = subject.flip()
        expect(error).to(beNil())
        expect(subject.isOn).to(beTrue())

        error = subject.flip()
        expect(error).to(beNil())
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenSwitchIsNotVisible_doesNotChangeTheSwitchAndReturnsError() {
        let subject = UISwitch()
        subject.isHidden = true
        subject.isEnabled = true
        expect(subject.isOn).to(beFalse())

        let error = subject.flip()
        expect(error?.description).to(equal("Fleet error: Cannot flip UISwitch: Control is not visible"))
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenSwitchIsNotEnabled_doesNotChangeTheSwitchAndReturnsError() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = false
        expect(subject.isOn).to(beFalse())

        let error = subject.flip()
        expect(error?.description).to(equal("Fleet error: Cannot flip UISwitch: Control is not enabled"))
        expect(subject.isOn).to(beFalse())
    }
}
