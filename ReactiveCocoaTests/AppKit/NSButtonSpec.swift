#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import AppKit

class NSButtonSpec: QuickSpec {
	override func spec() {

		// Creates a temporary test subject, runs the specified testing block that receives the subject,
		// and checks if the subject is released.
		func test(_ subject: (NSButton) -> Void) {
			weak var reference: NSButton?
			autoreleasepool {
				let window = NSWindow()
				let button = NSButton(frame: .zero)
				reference = button
				window.contentView?.addSubview(button)
				subject(button)
				button.removeFromSuperview()
			}
			expect(reference).to(beNil())
		}

		it("should accept changes from bindings to its enabling state") {
			test { button in
				button.isEnabled = false

				let (pipeSignal, observer) = Signal<Bool, Never>.pipe()
				button.reactive.isEnabled <~ SignalProducer(pipeSignal)

				observer.send(value: true)
				expect(button.isEnabled) == true

				observer.send(value: false)
				expect(button.isEnabled) == false
			}
		}

		it("should accept changes from bindings to its state") {
			test { button in
				button.allowsMixedState = true
				button.state = RACNSOffState

				let (pipeSignal, observer) = Signal<RACNSControlState, Never>.pipe()
				button.reactive.state <~ SignalProducer(pipeSignal)

				observer.send(value: RACNSOffState)
				expect(button.state) == RACNSOffState

				observer.send(value: RACNSMixedState)
				expect(button.state) == RACNSMixedState

				observer.send(value: RACNSOnState)
				expect(button.state) == RACNSOnState
			}
		}

		it("should send along state changes") {
			test { button in
				button.setButtonType(.pushOnPushOff)
				button.allowsMixedState = false
				button.state = RACNSOffState

				let state = MutableProperty(RACNSOffState)
				state <~ button.reactive.states

				button.performClick(nil)
				expect(state.value) == RACNSOnState

				button.performClick(nil)
				expect(state.value) == RACNSOffState

				button.allowsMixedState = true

				button.performClick(nil)
				expect(state.value) == RACNSMixedState

				button.performClick(nil)
				expect(state.value) == RACNSOnState

				button.performClick(nil)
				expect(state.value) == RACNSOffState
			}
		}
		
		it("should send along state changes embedded within NSStackView") {
			let window = NSWindow()
			let button1 = NSButton()
			let button2 = NSButton()
			
			button1.setButtonType(.pushOnPushOff)
			button1.allowsMixedState = false
			button1.state = RACNSOffState
			
			button2.setButtonType(.pushOnPushOff)
			button2.allowsMixedState = false
			button2.state = RACNSOnState
			
			let stackView = NSStackView()
			stackView.addArrangedSubview(button1)
			stackView.addArrangedSubview(button2)
			
			// This is required to avoid crashing as of 10.15, see https://github.com/ReactiveCocoa/ReactiveCocoa/issues/3690
			stackView.detachesHiddenViews = false
			
			window.contentView?.addSubview(stackView)
			
			let state = MutableProperty(RACNSOffState)
			state <~ button1.reactive.states
			state <~ button2.reactive.states
			
			button1.performClick(nil)
			expect(state.value) == RACNSOnState
			
			button2.performClick(nil)
			expect(state.value) == RACNSOffState
			
			autoreleasepool {
				button1.removeFromSuperview()
				button2.removeFromSuperview()
				stackView.removeFromSuperview()
			}
		}

		it("should execute the `pressed` action upon receiving a click") {
			test { button in
				button.isEnabled = true

				let pressed = MutableProperty(false)

				let (executionSignal, observer) = Signal<Bool, Never>.pipe()
				let action = Action<(), Bool, Never> { _ in
					SignalProducer(executionSignal)
				}

				pressed <~ SignalProducer(action.values)
				button.reactive.pressed = CocoaAction(action)
				expect(pressed.value) == false

				button.performClick(nil)
				expect(button.isEnabled) == false

				observer.send(value: true)
				observer.sendCompleted()

				expect(button.isEnabled) == true
				expect(pressed.value) == true
			}
		}
	}
}
#endif
