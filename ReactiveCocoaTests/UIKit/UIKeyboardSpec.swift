import UIKit
import ReactiveSwift
import ReactiveCocoa
import Quick
import Nimble

class UIKeyboardSpec: QuickSpec {
	override func spec() {
		describe("NotificationCenter.reactive.keyboardChange") {
			it("should emit a `value` event when the notification is posted") {
				var context: KeyboardChangeContext?

				let testCenter = NotificationCenter()

				testCenter.reactive.keyboardChange
					.observeValues { context = $0 }

				var dummyInfo: [AnyHashable: Any] = [
					UIKeyboardFrameBeginUserInfoKey: CGRect(x: 10, y: 10, width: 10, height: 10),
					UIKeyboardFrameEndUserInfoKey: CGRect(x: 20, y: 20, width: 20, height: 20),
					UIKeyboardAnimationDurationUserInfoKey: 1.0,
					UIKeyboardAnimationCurveUserInfoKey: NSNumber(value: UIViewAnimationCurve.easeInOut.rawValue)
				]

				if #available(*, iOS 9.0) {
					dummyInfo[UIKeyboardIsLocalUserInfoKey] = NSNumber(value: true)
				}

				testCenter.post(name: .UIKeyboardWillChangeFrame,
				                object: nil,
				                userInfo: dummyInfo)

				expect(context).toNot(beNil())

				expect(context?.beginFrame) == CGRect(x: 10, y: 10, width: 10, height: 10)
				expect(context?.endFrame) == CGRect(x: 20, y: 20, width: 20, height: 20)
				expect(context?.animationCurve) == .easeInOut
				expect(context?.animationDuration) == 1.0

				if #available(*, iOS 9.0) {
					expect(context?.isLocal) == true
				}
			}
		}
	}
}
