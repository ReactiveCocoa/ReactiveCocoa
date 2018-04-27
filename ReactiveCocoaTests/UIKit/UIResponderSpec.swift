import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa

class UIResponderSpec: QuickSpec {
	override func spec() {
		it("should become and resign first responder") {
			let window = UIWindow(frame: .zero)
			let textField = UITextField(frame: .zero)
			window.addSubview(textField)
			
			expect(textField.isFirstResponder).to(beFalse())
			textField.reactive.becomeFirstResponder <~ SignalProducer(value: ())
			expect(textField.isFirstResponder).to(beTrue())
			textField.reactive.resignFirstResponder <~ SignalProducer(value: ())
			expect(textField.isFirstResponder).to(beFalse())
		}
	}
}
