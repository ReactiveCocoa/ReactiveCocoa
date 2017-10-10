import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import AppKit
import enum Result.NoError

class NSButtonSpec: QuickSpec {
	override func spec() {
		var button: NSButton!
		weak var _button: NSButton?
		
		var window: NSWindow!

		beforeEach {
			button = NSButton(frame: .zero)
			_button = button
			window = NSWindow()
			window.contentView?.addSubview(button)
		}

		afterEach {
			autoreleasepool {
				button.removeFromSuperview()
				button = nil
			}
			expect(_button).to(beNil())
		}

		it("should accept changes from bindings to its enabling state") {
			button.isEnabled = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			button.reactive.isEnabled <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(button.isEnabled) == true

			observer.send(value: false)
			expect(button.isEnabled) == false
		}

		it("should accept changes from bindings to its state") {
			button.allowsMixedState = true
			button.state = RACNSOffState

			let (pipeSignal, observer) = Signal<RACNSControlState, NoError>.pipe()
			button.reactive.state <~ SignalProducer(pipeSignal)

			observer.send(value: RACNSOffState)
			expect(button.state) == RACNSOffState

			observer.send(value: RACNSMixedState)
			expect(button.state) == RACNSMixedState

			observer.send(value: RACNSOnState)
			expect(button.state) == RACNSOnState
		}

		it("should send along state changes") {
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
		
		if #available(OSX 10.11, *) {
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
		}

		it("should execute the `pressed` action upon receiving a click") {
			button.isEnabled = true

			let pressed = MutableProperty(false)

			let (executionSignal, observer) = Signal<Bool, NoError>.pipe()
			let action = Action<(), Bool, NoError> { _ in
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

