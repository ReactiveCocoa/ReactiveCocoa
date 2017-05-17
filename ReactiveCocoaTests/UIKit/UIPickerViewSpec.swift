import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

private final class PickerDataSource: NSObject, UIPickerViewDataSource {
	@objc func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 2
	}

	@objc func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return 4
	}
}

final class UIPickerViewSpec: QuickSpec {
	override func spec() {
		var dataSource: UIPickerViewDataSource!
		var pickerView: TestPickerView!
		weak var _pickerView: UIPickerView?

		beforeEach {
			autoreleasepool {
				dataSource = PickerDataSource()

				pickerView = TestPickerView()
				pickerView.dataSource = dataSource
				pickerView.reloadAllComponents()
				_pickerView = pickerView
			}
		}

		afterEach {
			autoreleasepool {
				dataSource = nil
				pickerView = nil
			}
			expect(_pickerView).toEventually(beNil())
		}

		it("should accept changes from bindings to selected rows") {

			let (pipeSignal, observer) = Signal<Int, NoError>.pipe()
			pickerView.reactive.selectedRow(inComponent: 0) <~ SignalProducer(pipeSignal)

			let (anotherPipeSignal, anotherObserver) = Signal<Int, NoError>.pipe()
			pickerView.reactive.selectedRow(inComponent: 1) <~ SignalProducer(anotherPipeSignal)

			observer.send(value: 1)
			expect(pickerView.selectedRow(inComponent: 0)) == 1

			anotherObserver.send(value: 3)
			expect(pickerView.selectedRow(inComponent: 1)) == 3

			observer.send(value: 2)
			expect(pickerView.selectedRow(inComponent: 0)) == 2
		}

		it("should emit user initiated changes for row selection") {
			var latestValue: (row: Int, component: Int)!
			pickerView.reactive.selections.observeValues {
				latestValue = $0
			}

			pickerView.selectRow(1, inComponent: 0, animated: false)
			pickerView.delegate!.pickerView!(pickerView, didSelectRow: 1, inComponent: 0)
			expect(latestValue.component) == 0
			expect(latestValue.row) == 1

			pickerView.selectRow(2, inComponent: 1, animated: false)
			pickerView.delegate!.pickerView!(pickerView, didSelectRow: 2, inComponent: 1)
			expect(latestValue.component) == 1
			expect(latestValue.row) == 2
		}

		it("invokes reloadAllComponents whenever the bound signal sends a value") {
			let (signal, observer) = Signal<(), NoError>.pipe()

			var reloadAllComponentsCount = 0

			pickerView.reloadAllComponentsSignal.observeValues {
				reloadAllComponentsCount += 1
			}

			pickerView.reactive.reloadAllComponents <~ signal

			observer.send(value: ())
			observer.send(value: ())

			expect(reloadAllComponentsCount) == 2
		}

		it("invokes reloadComponent whenever the bound signal sends a value") {
			let (signal, observer) = Signal<Int, NoError>.pipe()

			var reloadFirstComponentCount = 0
			var reloadSecondComponentCount = 0

			pickerView.reloadComponentSignal.observeValues { component in
				if (component == 0) {
					reloadFirstComponentCount += 1
				} else if (component == 1) {
					reloadSecondComponentCount += 1
				}
			}

			pickerView.reactive.reloadComponent <~ signal

			observer.send(value: 3)
			expect(reloadFirstComponentCount) == 0
			expect(reloadSecondComponentCount) == 0

			observer.send(value: 0)
			observer.send(value: 0)
			expect(reloadFirstComponentCount) == 2

			observer.send(value: 1)
			expect(reloadSecondComponentCount) == 1
		}
	}
}

private final class TestPickerView: UIPickerView {
	let reloadAllComponentsSignal: Signal<(), NoError>
	private let reloadAllComponentsObserver: Signal<(), NoError>.Observer

	let reloadComponentSignal: Signal<Int, NoError>
	private let reloadComponentObserver: Signal<Int, NoError>.Observer

	init() {
		(reloadAllComponentsSignal, reloadAllComponentsObserver) = Signal.pipe()
		(reloadComponentSignal, reloadComponentObserver) = Signal.pipe()
		super.init(frame: .zero)
	}

	required init?(coder aDecoder: NSCoder) {
		(reloadAllComponentsSignal, reloadAllComponentsObserver) = Signal.pipe()
		(reloadComponentSignal, reloadComponentObserver) = Signal.pipe()
		super.init(coder: aDecoder)
	}

	override func reloadAllComponents() {
		super.reloadAllComponents()
		reloadAllComponentsObserver.send(value: ())
	}

	override func reloadComponent(_ component: Int) {
		super.reloadComponent(component)
		reloadComponentObserver.send(value: component)
	}
}
