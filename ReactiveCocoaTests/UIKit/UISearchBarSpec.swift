import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UISearchBarSpec: QuickSpec {
	override func spec() {
		var searchBar: UISearchBar!
		weak var _searchBar: UISearchBar?


		beforeEach {
			autoreleasepool {
				searchBar = UISearchBar(frame: .zero)
				_searchBar = searchBar
			}
		}

		afterEach {
			autoreleasepool {
				searchBar = nil
			}
			expect(_searchBar).toEventually(beNil())
		}

		it("should accept changes from bindings to its text value") {
			let firstChange = "first"
			let secondChange = "second"

			searchBar.text = ""

			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			searchBar.reactive.text <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(searchBar.text) == firstChange

			observer.send(value: secondChange)
			expect(searchBar.text) == secondChange
		}

		it("should emit user initiated changes to its text value when the editing ends") {
			searchBar.text = "Test"

			var latestValue: String?
			searchBar.reactive.textValues.observeValues { text in
				latestValue = text
			}

			searchBar.delegate!.searchBarTextDidEndEditing!(searchBar)

			expect(latestValue) == searchBar.text
		}

		it("should emit user initiated changes to its text value continuously") {
			searchBar.text = "newValue"

			var latestValue: String?
			searchBar.reactive.continuousTextValues.observeValues { text in
				latestValue = text
			}

			searchBar.delegate!.searchBar!(searchBar, textDidChange: "newValue")
			expect(latestValue) == "newValue"
		}
	}
}
