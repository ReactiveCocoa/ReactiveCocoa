import Result
import Nimble
import Quick
import ReactiveCocoa

class CocoaActionSpec: QuickSpec {
	override func spec() {
		var action: Action<Int, Int, NoError>!

		beforeEach {
			action = Action { value in SignalProducer(value: value + 1) }
			expect(action.enabled.value) == true

			expect(action.unsafeCocoaAction.enabled).toEventually(beTruthy())
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
				let control = UIControl(frame: CGRectZero)
				control.addTarget(action.unsafeCocoaAction, action: CocoaAction.selector, forControlEvents: UIControlEvents.TouchDown)
				control.sendActionsForControlEvents(UIControlEvents.TouchDown)
			}
		#endif

		it("should generate KVO notifications for enabled") {
			var values: [Bool] = []

			let cocoaAction = action.unsafeCocoaAction
			cocoaAction
				.rac_valuesForKeyPath("enabled", observer: nil)
				.toSignalProducer()
				.map { $0! as! Bool }
				.start(Observer(next: { values.append($0) }))

			expect(values) == [ true ]

			let result = action.apply(0).first()
			expect(result?.value) == 1
			expect(values).toEventually(equal([ true, false, true ]))
			
			_ = cocoaAction
		}

		it("should generate KVO notifications for executing") {
			var values: [Bool] = []

			let cocoaAction = action.unsafeCocoaAction
			cocoaAction
				.rac_valuesForKeyPath("executing", observer: nil)
				.toSignalProducer()
				.map { $0! as! Bool }
				.start(Observer(next: { values.append($0) }))

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
