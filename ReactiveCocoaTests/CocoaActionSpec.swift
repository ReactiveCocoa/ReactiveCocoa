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

			expect(action.unsafeCocoaAction.isEnabled).toEventually(beTruthy())
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

		it("should generate KVO notifications for enabled") {
			var values: [Bool] = []

			let cocoaAction = action.unsafeCocoaAction
			cocoaAction
				.values(forKeyPath: #keyPath(CocoaAction.isEnabled))
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
				.values(forKeyPath: #keyPath(CocoaAction.isExecuting))
				.map { $0! as! Bool }
				.start(Observer(next: { values.append($0) }))

			expect(values) == [ false ]

			let result = action.apply(0).first()
			expect(result?.value) == 1
			expect(values).toEventually(equal([ false, true, false ]))
			
			_ = cocoaAction
		}

		it("ignores the input when initialized with a void action") {
			let action = Action<Void, Int, NoError> { SignalProducer(value: 1) }

			var result: Int?
			action.values.observeResult { result = $0.value }

			CocoaAction(action).execute(NSObject())

			expect(result) == 1
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
