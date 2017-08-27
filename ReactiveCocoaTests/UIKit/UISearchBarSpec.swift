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

		it("should pass through the intercepted calls") {
			searchBar.text = "newValue"

			var latestValue: String?
			searchBar.reactive.continuousTextValues.observeValues { text in
				latestValue = text
			}

			let receiver = SearchBarDelegateReceiver()
			searchBar.delegate = receiver
			expect(receiver.textDidChangeCounter) == 0

			searchBar.delegate!.searchBar!(searchBar, textDidChange: "newValue")
			expect(latestValue) == "newValue"
			expect(receiver.textDidChangeCounter) == 1
		}

		it("should pass through the unintercepted calls") {
			searchBar.reactive.continuousTextValues.observe { _ in }

			let receiver = SearchBarDelegateReceiver()
			searchBar.delegate = receiver
			expect(receiver.searchButtonClickedCounter) == 0

			searchBar.delegate!.searchBarSearchButtonClicked!(searchBar)
			expect(receiver.searchButtonClickedCounter) == 1
		}

		it("should preserve the original delegate, and pass through the unintercepted calls") {
			let receiver = SearchBarDelegateReceiver()
			searchBar.delegate = receiver
			expect(receiver.searchButtonClickedCounter) == 0

			searchBar.reactive.continuousTextValues.observe { _ in }
			expect(receiver.searchButtonClickedCounter) == 0

			searchBar.delegate!.searchBarSearchButtonClicked!(searchBar)
			expect(receiver.searchButtonClickedCounter) == 1
		}
		
		it("should pass through the unintercepted calls") {
			searchBar.reactive.continuousTextValues.observe { _ in }
			
			let receiver = SearchBarDelegateReceiver()
			searchBar.delegate = receiver
			expect(receiver.searchBarCancelButtonClickedCounter) == 0
			
			searchBar.delegate!.searchBarCancelButtonClicked!(searchBar)
			expect(receiver.searchBarCancelButtonClickedCounter) == 1
		}
		
	}
}

class SearchBarDelegateReceiver: NSObject, UISearchBarDelegate {
	var textDidChangeCounter = 0
	var textDidEndEditingCounter = 0
	var searchButtonClickedCounter = 0
	var searchBarCancelButtonClickedCounter = 0

	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchButtonClickedCounter += 1
	}

	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		textDidChangeCounter += 1
	}

	func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
		textDidEndEditingCounter += 1
	}
	
	func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		searchBarCancelButtonClickedCounter += 1
	}
}
