import ReactiveSwift
import Result
import Nimble
import Quick
import ReactiveCocoa

class CocoaActionSpec: QuickSpec {
	override func spec() {
		var action: Action<Int, Int, NoError>!

		beforeEach {
			action = Action { value in SignalProducer(value: value + 1) }
			expect(action.isEnabled.value) == true

			expect(action.unsafeCocoaAction.isEnabled.value).toEventually(beTruthy())
		}

		#if os(OSX)
			it("should be compatible with AppKit") {
				let control = NSControl(frame: NSZeroRect)
				control.target = action.unsafeCocoaAction
				control.action = CocoaAction.selector
				control.performClick(nil)
			}
		#elseif os(iOS)
			it("should be compatible with UIKit") {
				let control = UIControl(frame: .zero)
				control.addTarget(action.unsafeCocoaAction, action: CocoaAction.selector, for: .touchDown)
				control.sendActions(for: .touchDown)
			}
		#endif

		it("should emit changes for enabled") {
			var values: [Bool] = []

			let cocoaAction = action.unsafeCocoaAction
			cocoaAction.isEnabled.producer
				.startWithValues { values.append($0) }

			expect(values) == [ true ]

			let result = action.apply(0).first()
			expect(result?.value) == 1
			expect(values).toEventually(equal([ true, false, true ]))
			
			_ = cocoaAction
		}

		it("should generate KVO notifications for executing") {
			var values: [Bool] = []

			let cocoaAction = action.unsafeCocoaAction
			cocoaAction.isExecuting.producer
				.startWithValues { values.append($0) }

			expect(values) == [ false ]

			let result = action.apply(0).first()
			expect(result?.value) == 1
			expect(values).toEventually(equal([ false, true, false ]))
			
			_ = cocoaAction
		}
		
		context("lifetime") {
			it("unsafeCocoaAction should not create a retain cycle") {
				weak var weakAction: Action<Int, Int, NoError>?
				var action: Action<Int, Int, NoError>? = Action { _ in
					return SignalProducer(value: 42)
				}
				weakAction = action
				expect(weakAction).notTo(beNil())
				
				_ = action!.unsafeCocoaAction
				action = nil
				expect(weakAction).to(beNil())
			}
		}
	}
}
