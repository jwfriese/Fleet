import UIKit

class UIControlEventRecorder: NSObject {
    private(set) var recordedEvents: [UIControlEvents] = []

    func registerAllEvents(for control: UIControl) {
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordTouchDown(sender:)), for: .touchDown)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordTouchDownRepeat(sender:)), for: .touchDownRepeat)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordTouchDragInside(sender:)), for: .touchDragInside)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordTouchDragEnter(sender:)), for: .touchDragEnter)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordTouchDragExit(sender:)), for: .touchDragExit)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordTouchUpInside(sender:)), for: .touchUpInside)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordTouchUpOutside(sender:)), for: .touchUpOutside)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordTouchCancel(sender:)), for: .touchCancel)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordValueChanged(sender:)), for: .valueChanged)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordEditingDidBegin(sender:)), for: .editingDidBegin)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordEditingChanged(sender:)), for: .editingChanged)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordEditingDidEnd(sender:)), for: .editingDidEnd)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordEditingDidEndOnExit(sender:)), for: .editingDidEndOnExit)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordAllTouchEvents(sender:)), for: .allTouchEvents)
        control.addTarget(self, action: #selector(UIControlEventRecorder.recordAllEditingEvents(sender:)), for: .allEditingEvents)
        erase()
    }

    func erase() {
        recordedEvents = []
    }

    @objc fileprivate func recordTouchDown(sender: UIControl) {
        recordedEvents.append(.touchDown)
    }

    @objc fileprivate func recordTouchDownRepeat(sender: UIControl) {
        recordedEvents.append(.touchDownRepeat)
    }

    @objc fileprivate func recordTouchDragInside(sender: UIControl) {
        recordedEvents.append(.touchDragInside)
    }

    @objc fileprivate func recordTouchDragEnter(sender: UIControl) {
        recordedEvents.append(.touchDragEnter)
    }

    @objc fileprivate func recordTouchDragExit(sender: UIControl) {
        recordedEvents.append(.touchDragExit)
    }

    @objc fileprivate func recordTouchUpInside(sender: UIControl) {
        recordedEvents.append(.touchUpInside)
    }

    @objc fileprivate func recordTouchUpOutside(sender: UIControl) {
        recordedEvents.append(.touchUpOutside)
    }

    @objc fileprivate func recordTouchCancel(sender: UIControl) {
        recordedEvents.append(.touchCancel)
    }

    @objc fileprivate func recordValueChanged(sender: UIControl) {
        recordedEvents.append(.valueChanged)
    }

    @objc fileprivate func recordEditingDidBegin(sender: UIControl) {
        recordedEvents.append(.editingDidBegin)
    }

    @objc fileprivate func recordEditingChanged(sender: UIControl) {
        recordedEvents.append(.editingChanged)
    }

    @objc fileprivate func recordEditingDidEnd(sender: UIControl) {
        recordedEvents.append(.editingDidEnd)
    }

    @objc fileprivate func recordEditingDidEndOnExit(sender: UIControl) {
        recordedEvents.append(.editingDidEndOnExit)
    }

    @objc fileprivate func recordAllTouchEvents(sender: UIControl) {
        recordedEvents.append(.allTouchEvents)
    }

    @objc fileprivate func recordAllEditingEvents(sender: UIControl) {
        recordedEvents.append(.allEditingEvents)
    }
}
