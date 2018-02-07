import UIKit
import ReactiveSwift
import ReactiveCocoa
import Quick
import Nimble

class UIKeyboardSpec: QuickSpec {
	override func spec() {
		describe("NotificationCenter.reactive.keyboard(_;)") {
			it("should emit a `value` event when the notification is posted") {
				var context: KeyboardChangeContext?
				
				let testCenter = NotificationCenter()
				
				testCenter.reactive.keyboard(.willShow)
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
				
				testCenter.post(name: .UIKeyboardWillShow,
				                object: nil,
				                userInfo: dummyInfo)
				
				expect(context).toNot(beNil())
				
				expect(context?.event) == .willShow
				expect(context?.beginFrame) == CGRect(x: 10, y: 10, width: 10, height: 10)
				expect(context?.endFrame) == CGRect(x: 20, y: 20, width: 20, height: 20)
				expect(context?.animationCurve) == .easeInOut
				expect(context?.animationDuration) == 1.0
				
				if #available(*, iOS 9.0) {
					expect(context?.isLocal) == true
				}
			}
		}
		
		describe("NotificationCenter.reactive.keyboard(_:_:_;)") {
			it("should emit a `value` event when the notification is posted") {
				var context: KeyboardChangeContext?
				
				let testCenter = NotificationCenter()
				
				testCenter.reactive.keyboard(.willShow, .didShow, .willHide, .didHide, .willChangeFrame, .didChangeFrame)
					.observeValues { context = $0 }
				
				func makeDummyInfo(beginFrameHeight: CGFloat) -> [AnyHashable: Any] {
					var dummyInfo: [AnyHashable: Any] = [
						UIKeyboardFrameBeginUserInfoKey: CGRect(x: 10, y: 10, width: 10, height: beginFrameHeight),
						UIKeyboardFrameEndUserInfoKey: CGRect(x: 20, y: 20, width: 20, height: 20),
						UIKeyboardAnimationDurationUserInfoKey: 1.0,
						UIKeyboardAnimationCurveUserInfoKey: NSNumber(value: UIViewAnimationCurve.easeInOut.rawValue)
					]
					if #available(*, iOS 9.0) {
						dummyInfo[UIKeyboardIsLocalUserInfoKey] = NSNumber(value: true)
					}
					return dummyInfo
				}
				
				testCenter.post(name: .UIKeyboardWillShow,
				                object: nil,
				                userInfo: makeDummyInfo(beginFrameHeight: 10))
				
				expect(context).toNot(beNil())
				
				expect(context?.event) == .willShow
				expect(context?.beginFrame) == CGRect(x: 10, y: 10, width: 10, height: 10)
				expect(context?.endFrame) == CGRect(x: 20, y: 20, width: 20, height: 20)
				expect(context?.animationCurve) == .easeInOut
				expect(context?.animationDuration) == 1.0
				
				if #available(*, iOS 9.0) {
					expect(context?.isLocal) == true
				}
				
				testCenter.post(name: .UIKeyboardDidShow,
				                object: nil,
				                userInfo: makeDummyInfo(beginFrameHeight: 20))
				
				expect(context?.event) == .didShow
				expect(context?.beginFrame) == CGRect(x: 10, y: 10, width: 10, height: 20)
				expect(context?.endFrame) == CGRect(x: 20, y: 20, width: 20, height: 20)
				expect(context?.animationCurve) == .easeInOut
				expect(context?.animationDuration) == 1.0
				
				if #available(*, iOS 9.0) {
					expect(context?.isLocal) == true
				}
				
				testCenter.post(name: .UIKeyboardWillHide,
				                object: nil,
				                userInfo: makeDummyInfo(beginFrameHeight: 30))
				
				expect(context?.event) == .willHide
				expect(context?.beginFrame) == CGRect(x: 10, y: 10, width: 10, height: 30)
				expect(context?.endFrame) == CGRect(x: 20, y: 20, width: 20, height: 20)
				expect(context?.animationCurve) == .easeInOut
				expect(context?.animationDuration) == 1.0
				
				if #available(*, iOS 9.0) {
					expect(context?.isLocal) == true
				}
				
				testCenter.post(name: .UIKeyboardDidHide,
				                object: nil,
				                userInfo: makeDummyInfo(beginFrameHeight: 40))
				
				expect(context?.event) == .didHide
				expect(context?.beginFrame) == CGRect(x: 10, y: 10, width: 10, height: 40)
				expect(context?.endFrame) == CGRect(x: 20, y: 20, width: 20, height: 20)
				expect(context?.animationCurve) == .easeInOut
				expect(context?.animationDuration) == 1.0
				
				if #available(*, iOS 9.0) {
					expect(context?.isLocal) == true
				}
				
				testCenter.post(name: .UIKeyboardWillChangeFrame,
				                object: nil,
				                userInfo: makeDummyInfo(beginFrameHeight: 50))
				
				expect(context?.event) == .willChangeFrame
				expect(context?.beginFrame) == CGRect(x: 10, y: 10, width: 10, height: 50)
				expect(context?.endFrame) == CGRect(x: 20, y: 20, width: 20, height: 20)
				expect(context?.animationCurve) == .easeInOut
				expect(context?.animationDuration) == 1.0
				
				if #available(*, iOS 9.0) {
					expect(context?.isLocal) == true
				}
				
				testCenter.post(name: .UIKeyboardDidChangeFrame,
				                object: nil,
				                userInfo: makeDummyInfo(beginFrameHeight: 60))
				
				expect(context?.event) == .didChangeFrame
				expect(context?.beginFrame) == CGRect(x: 10, y: 10, width: 10, height: 60)
				expect(context?.endFrame) == CGRect(x: 20, y: 20, width: 20, height: 20)
				expect(context?.animationCurve) == .easeInOut
				expect(context?.animationDuration) == 1.0
				
				if #available(*, iOS 9.0) {
					expect(context?.isLocal) == true
				}
			}
		}
		
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
				
				expect(context?.event) == .willChangeFrame
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
