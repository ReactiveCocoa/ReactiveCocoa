import Nimble
import Quick
import ReactiveSwift
import ReactiveCocoa
import Result

private final class MockControl<Value> {
	var isEnabled = true
	var value: Value

	var actionBindable: ActionBindable<MockControl, Value> {
		return ActionBindable(owner: self,
		                     isEnabled: \.isEnabled,
		                     values: { $0.signal })
	}

	var valueBindable: ValueBindable<MockControl, Value> {
		return ValueBindable(owner: self,
		                     isEnabled: \.isEnabled,
		                     value: \.value,
		                     values: { $0.signal })
	}

	let (signal, observer) = Signal<Value, NoError>.pipe()

	init(_ initial: Value) {
		value = initial
	}

	func emulateUserInput(_ input: Value) {
		value = input
		observer.send(value: input)
	}
}

enum TestValue: Equatable {
    case undefined
    case initial
    case subsequent
    case final
}

class BidirectionalBindingSpec: QuickSpec {
	override func spec() {
		func itShouldTrackAvailabilityOfTheBoundAction<Bindable: ActionBindableProtocol>(
			_ control: MockControl<TestValue>,
			_ bindable: Bindable
		) where Bindable.Value == TestValue {
			let (pipe, observer) = Signal<Never, NoError>.pipe()

			let action = Action<TestValue, Never, NoError> { _ in
				return SignalProducer(pipe)
			}

			control.isEnabled = false
			expect(action.isEnabled.value) == true

			action <~> bindable
			expect(action.isEnabled.value) == true
			expect(control.isEnabled) == true

			action.apply(.initial).start()
			expect(action.isEnabled.value) == false
			expect(control.isEnabled) == false

			observer.sendCompleted()
			expect(action.isEnabled.value) == true
			expect(control.isEnabled) == true
		}

		func itShouldStartTheActionForEveryUserInput<Bindable: ActionBindableProtocol>(
			_ control: MockControl<TestValue>,
			_ bindable: Bindable
		) where Bindable.Value == TestValue {
			let (pipe, observer) = Signal<(), NoError>.pipe()
			var values: [TestValue] = []

			let action = Action<TestValue, Never, NoError> { input in
				return SignalProducer
					.never
					.take(until: pipe)
					.on(started: { values.append(input) })
			}

			var disabledActionCount = 0
			action.disabledErrors.observeValues { disabledActionCount += 1 }

			action <~> bindable

			control.emulateUserInput(.undefined)
			expect(values) == [.undefined]
			expect(disabledActionCount) == 0

			control.emulateUserInput(.initial)
			expect(values) == [.undefined]
			observer.send(value: ())
			expect(disabledActionCount) == 1

			control.emulateUserInput(.subsequent)
			expect(values) == [.undefined, .subsequent]
			observer.send(value: ())
			expect(disabledActionCount) == 1

			control.emulateUserInput(.final)
			expect(values) == [.undefined, .subsequent, .final]
			observer.send(value: ())
			expect(disabledActionCount) == 1
		}

		describe("ActionBindable") {
			var actionBindable: ActionBindable<MockControl<TestValue>, TestValue>!
			var control: MockControl<TestValue>!

			beforeEach {
				control = MockControl(.undefined)
				actionBindable = control.actionBindable
			}

			afterEach {
				weak var weakControl = control
				control = nil

				expect(weakControl).to(beNil())
			}

			it("should track the availability of the bound action") {
				itShouldTrackAvailabilityOfTheBoundAction(control, actionBindable)
			}

			it("should start the action for every user input") {
				itShouldStartTheActionForEveryUserInput(control, actionBindable)
			}
		}

		describe("ValueBindable") {
            var source: MutableProperty<TestValue>!
			var valueBindable: ValueBindable<MockControl<TestValue>, TestValue>!
			var control: MockControl<TestValue>!

			beforeEach {
                control = MockControl(.undefined)
				valueBindable = control.valueBindable
                source = MutableProperty(.initial)
			}

			afterEach {
				weak var weakControl = control
				control = nil

				expect(weakControl).to(beNil())
			}

            it("should initialize the control") {
                expect(control?.value) == .undefined

                source <~> valueBindable
                expect(control?.value) == .initial
                expect(source?.value) == .initial
            }

            it("should immediately propagate mutations from the source") {
                source <~> valueBindable
                expect(control?.value) == .initial
                expect(source?.value) == .initial

                source.value = .subsequent
                expect(control?.value) == .subsequent
                expect(source?.value) == .subsequent

                source.value = .final
                expect(control?.value) == .final
                expect(source?.value) == .final
            }

            it("should immediately propagate user inputs from the control") {
                source <~> valueBindable
                expect(control?.value) == .initial
                expect(source?.value) == .initial

                control.emulateUserInput(.subsequent)
                expect(control?.value) == .subsequent
                expect(source?.value) == .subsequent

                control.emulateUserInput(.final)
                expect(control?.value) == .final
                expect(source?.value) == .final
            }

            it("should immediately propagate user input from the control, and then propagate mutations from the source") {
                source <~> valueBindable
                expect(control?.value) == .initial
                expect(source?.value) == .initial

                control.emulateUserInput(.subsequent)
                expect(control?.value) == .subsequent
                expect(source?.value) == .subsequent

                source.value = .final
                expect(control?.value) == .final
                expect(source?.value) == .final
            }

            it("should immediately propagate mutations from the source, and then propagate user input from the control") {
                source <~> valueBindable
                expect(control?.value) == .initial
                expect(source?.value) == .initial

                source.value = .subsequent
                expect(control?.value) == .subsequent
                expect(source?.value) == .subsequent

                control.emulateUserInput(.final)
                expect(control?.value) == .final
                expect(source?.value) == .final
            }

			it("should track the availability of the bound action") {
				itShouldTrackAvailabilityOfTheBoundAction(control, valueBindable)
			}

			it("should start the action for every user input") {
				itShouldStartTheActionForEveryUserInput(control, valueBindable)
			}
		}
	}
}
