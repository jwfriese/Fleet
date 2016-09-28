import UIKit

class CrabViewController: UIViewController {
    @IBOutlet weak var allowTextEditingSwitch: UISwitch?
    @IBOutlet weak var enabledTextField: UITextField?
    @IBOutlet weak var disabledTextField: UITextField?
}

extension CrabViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        let textFieldName = (textField === enabledTextField) ? "Enabled" : "Disabled"
        print("\(textFieldName) Text field SHOULD editing BEGIN")

        if allowTextEditingSwitch != nil && allowTextEditingSwitch!.isOn {
            return true
        }

        return false
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        let textFieldName = (textField === enabledTextField) ? "Enabled" : "Disabled"
        print("\(textFieldName) Text field SHOULD editing END")
        return true

    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let textFieldName = (textField === enabledTextField) ? "Enabled" : "Disabled"
        print("\(textFieldName) Text field editing BEGAN")
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        let textFieldName = (textField === enabledTextField) ? "Enabled" : "Disabled"
        print("\(textFieldName) Text field editing ENDED")
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let textFieldName = (textField === enabledTextField) ? "Enabled" : "Disabled"
        print("\(textFieldName) Text field editing CHANGED: \(string) (change size: \(string.characters.count))")
        return true
    }
}
