import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble

class UIDatePickerSpec: QuickSpec {
	override func spec() {
		var date: Date!
		var picker: UIDatePicker!
		weak var _picker: UIDatePicker?

		beforeEach {
			let formatter = DateFormatter()
			formatter.dateFormat = "MM/dd/YYYY"
			date = formatter.date(from: "11/29/1988")!

			picker = UIDatePicker(frame: .zero)
			_picker = picker
		}

		afterEach {
			picker = nil
			expect(_picker).to(beNil())
		}

		it("should accept changes from bindings to its date value") {
			picker.reactive.date.consume(date)
			expect(picker.date) == date
		}

		it("should emit user initiated changes to its date value") {
			let expectation = self.expectation(description: "Expected rac_date to send an event when picker's date value is changed by a UI event")
			defer { self.waitForExpectations(timeout: 2, handler: nil) }

			picker.reactive.dates.observeValues { changedDate in
				expect(changedDate) == date
				expectation.fulfill()
			}

			picker.date = date
			picker.isEnabled = true
			picker.isUserInteractionEnabled = true
			picker.sendActions(for: .valueChanged)
		}
	}
}
