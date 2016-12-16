import ReactiveSwift
import Result
import Nimble
import Quick
import ReactiveCocoa

class CocoaActionSpec: QuickSpec {
	override func spec() {
		var action: Action<Int, Int, NoError>!
		#if os(OSX)
			var cocoaAction: CocoaAction<NSControl>!
		#else
			var cocoaAction: CocoaAction<UIControl>!
		#endif

		beforeEach {
			action = Action { value in SignalProducer(value: value + 1) }
			expect(action.isEnabled.value) == true

			cocoaAction = CocoaAction(action) { _ in 1 }
			expect(cocoaAction.isEnabled.value).toEventually(beTruthy())
		}

		#if os(OSX)
			it("should be compatible with AppKit") {
				let control = NSControl(frame: NSZeroRect)
				control.target = cocoaAction
				control.action = CocoaAction<NSControl>.selector
				control.performClick(nil)
			}
		#elseif os(iOS)
			it("should be compatible with UIKit") {
				let control = UIControl(frame: .zero)
				control.addTarget(cocoaAction, action: CocoaAction<UIControl>.selector, for: .touchDown)
				control.sendActions(for: .touchDown)
			}
		#endif

		it("should emit changes for enabled") {
			var values: [Bool] = []

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

			cocoaAction.isExecuting.producer
				.startWithValues { values.append($0) }

			expect(values) == [ false ]

			let result = action.apply(0).first()
			expect(result?.value) == 1
			expect(values).toEventually(equal([ false, true, false ]))
			
			_ = cocoaAction
		}

		it("should emit `isExecuting` changes only on the main thread") {
			var counter = 0

			cocoaAction.isExecuting.producer
				.startWithValues { _ in
					counter += Thread.current.isMainThread ? 1 : 0
				}

			expect(counter) == 1

			action.apply(0).start()
			expect(counter) == 3
		}

		it("should emit `isEnabled` changes only on the main thread") {
			var counter = 0

			cocoaAction.isEnabled.producer
				.startWithValues { _ in
					counter += Thread.current.isMainThread ? 1 : 0
				}

			expect(counter) == 1

			action.apply(0).start()
			expect(counter) == 3
		}

		context("lifetime") {
			it("CocoaAction should not create a retain cycle") {
				weak var weakAction = action
				expect(weakAction).notTo(beNil())

				action = nil
				expect(weakAction).toNot(beNil())

				cocoaAction = nil
				expect(weakAction).to(beNil())
			}
		}
	}
}
