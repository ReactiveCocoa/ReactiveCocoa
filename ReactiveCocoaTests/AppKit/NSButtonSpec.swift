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

		beforeEach {
			button = NSButton(frame: .zero)
			_button = button
		}

		afterEach {
			button = nil
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
			button.state = NSOffState

			let (pipeSignal, observer) = Signal<Int, NoError>.pipe()
			button.reactive.state <~ SignalProducer(pipeSignal)

			observer.send(value: NSOffState)
			expect(button.state) == NSOffState

			observer.send(value: NSMixedState)
			expect(button.state) == NSMixedState

			observer.send(value: NSOnState)
			expect(button.state) == NSOnState
		}

		it("should send along state changes") {
			button.setButtonType(.pushOnPushOff)
			button.allowsMixedState = false
			button.state = NSOffState

			let state = MutableProperty(NSOffState)
			state <~ button.reactive.states

			button.performClick(nil)
			expect(state.value) == NSOnState

			button.performClick(nil)
			expect(state.value) == NSOffState

			button.allowsMixedState = true

			button.performClick(nil)
			expect(state.value) == NSMixedState

			button.performClick(nil)
			expect(state.value) == NSOnState

			button.performClick(nil)
			expect(state.value) == NSOffState

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

