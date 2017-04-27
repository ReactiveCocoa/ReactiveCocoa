import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import Result

class UISwitchSpec: QuickSpec {
	override func spec() {
		var toggle: UISwitch!
		weak var _toggle: UISwitch?

		beforeEach {
			toggle = UISwitch(frame: .zero)
			_toggle = toggle
		}

		afterEach {
			toggle = nil
			if #available(*, iOS 10.2) {
				expect(_toggle).to(beNil())
			}
		}

		it("should accept changes from bindings to its `isOn` state") {
			toggle.isOn = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			toggle.reactive.isOn <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(toggle.isOn) == true

			observer.send(value: false)
			expect(toggle.isOn) == false
		}

		it("should emit user initiated changes to its `isOn` state") {
			var latestValue: Bool?
			toggle.reactive.isOnValues.observeValues { latestValue = $0 }

			toggle.isOn = true
			toggle.sendActions(for: .valueChanged)
			expect(latestValue!) == true
		}

		it("should execute the `toggled` action upon receiving a `valueChanged` action message.") {
			toggle.isOn = false
			toggle.isEnabled = true
			toggle.isUserInteractionEnabled = true
			
			let isOn = MutableProperty(false)
			let action = Action<Bool, Bool, NoError> { isOn in
				return SignalProducer(value: isOn)
			}
			isOn <~ SignalProducer(action.values)
			
			toggle.reactive.toggled = CocoaAction(action) { return $0.isOn }
			
			expect(isOn.value) == false
			
			toggle.isOn = true
			toggle.sendActions(for: .valueChanged)
			expect(isOn.value) == true
			
			toggle.isOn = false
			toggle.sendActions(for: .valueChanged)
			expect(isOn.value) == false
			
		}
	}
}
