import XCTest
import Nimble
@testable import Fleet

class VisualTreeWalkerSpec: XCTestCase {
    var subject: VisualTreeWalker!

    var rootView: UIView!
    var viewOne: UIView!
    var viewTwo: UIView!
    var viewThree: UIView!
    var rabbitTitleButtonOne: UIButton!
    var rabbitTitleButtonTwo: UIButton!

    override func setUp() {
        super.setUp()

        subject = VisualTreeWalker()

        rootView = UIView()

        viewOne = UIView()
        viewOne.addSubview(UIButton())
        viewOne.addSubview(UIButton())
        viewOne.addSubview(UITextField())
        rabbitTitleButtonOne = UIButton()
        rabbitTitleButtonOne.titleLabel!.text = "Rabbit"
        viewOne.addSubview(rabbitTitleButtonOne)

        rootView.addSubview(viewOne)

        viewTwo = UIView()
        viewTwo.addSubview(UISwitch())

        viewThree = UIView()
        viewThree.addSubview(UIButton())
        viewThree.addSubview(UIView())
        viewThree.addSubview(UITextField())
        rabbitTitleButtonTwo = UIButton()
        rabbitTitleButtonTwo.titleLabel!.text = "Rabbit"
        viewThree.addSubview(rabbitTitleButtonTwo)

        viewTwo.addSubview(viewThree)

        rootView.addSubview(viewTwo)
    }

    func test_findAllSubviewsOfType_returnsAllSubviewsOfTheGivenType() {
        expect(self.subject.findAllSubviews(ofType: UITextField.self, inRootVisual:self.rootView).count).to(equal(2))

        let rabbitButtons = self.subject.findAllSubviews(ofType: UIButton.self, inRootVisual: self.rootView, conformingToBlock: { (button: UIButton) -> Bool in
            return button.titleLabel?.text == "Rabbit"
            })

        expect(rabbitButtons.count).to(equal(2))
        expect(rabbitButtons[0]).to(beIdenticalTo(rabbitTitleButtonOne))
        expect(rabbitButtons[1]).to(beIdenticalTo(rabbitTitleButtonTwo))
    }
}
