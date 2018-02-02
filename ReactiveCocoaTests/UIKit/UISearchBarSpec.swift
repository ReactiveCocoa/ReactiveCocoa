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
		var receiver: SearchBarDelegateReceiver!

		beforeEach {
			autoreleasepool {
				receiver = SearchBarDelegateReceiver()
				searchBar = UISearchBar(frame: .zero)
				_searchBar = searchBar

				_ = searchBar.reactive.textValues
				searchBar.delegate = receiver

				expect(searchBar.delegate).toNot(beIdenticalTo(receiver))
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

			expect(latestValue).to(beNil())
			expect(receiver.endEditingTexts.isEmpty) == true

			searchBar.delegate!.searchBarTextDidEndEditing!(searchBar)

			expect(latestValue) == searchBar.text
			expect(receiver.endEditingTexts.last) == searchBar.text
		}

		it("should emit user initiated changes to its text value continuously") {
			searchBar.text = "newValue"

			var latestValue: String?
			searchBar.reactive.continuousTextValues.observeValues { text in
				latestValue = text
			}

			expect(latestValue).to(beNil())
			expect(receiver.texts.isEmpty) == true

			searchBar.delegate!.searchBar!(searchBar, textDidChange: "newValue")
			expect(latestValue) == "newValue"
			expect(receiver.texts.last) == "newValue"
		}

		it("should accept changes from bindings to its scope button index") {
			let firstChange = 1
			let secondChange = 2

			searchBar.scopeButtonTitles = ["First", "Second", "Third"]

			let (pipeSignal, observer) = Signal<Int, NoError>.pipe()
			searchBar.reactive.selectedScopeButtonIndex <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(searchBar.selectedScopeButtonIndex) == firstChange

			observer.send(value: secondChange)
			expect(searchBar.selectedScopeButtonIndex) == secondChange
		}

		it("should emit user initiated changes to its text value when the editing ends") {
			searchBar.scopeButtonTitles = ["First", "Second", "Third"]

			var latestValue: Int?
			searchBar.reactive.selectedScopeButtonIndices.observeValues { text in
				latestValue = text
			}

			expect(latestValue).to(beNil())
			expect(receiver.selectedScopeButtonIndices.isEmpty) == true

			searchBar.delegate!.searchBar!(searchBar, selectedScopeButtonIndexDidChange: 1)

			expect(latestValue) == 1
			expect(receiver.selectedScopeButtonIndices.last) == 1

			searchBar.delegate!.searchBar!(searchBar, selectedScopeButtonIndexDidChange: 2)

			expect(latestValue) == 2
			expect(receiver.selectedScopeButtonIndices.last) == 2
		}

		it("should notify when the cancel button is clicked") {
			var isClicked: Bool?
			searchBar.reactive.cancelButtonClicked
				.observeValues { isClicked = true }

			expect(isClicked).to(beNil())
			expect(receiver.cancelButtonClickedCounter) == 0

			searchBar.delegate!.searchBarCancelButtonClicked!(searchBar)
			expect(isClicked) == true
			expect(receiver.cancelButtonClickedCounter) == 1
		}

		it("should notify when the search button is clicked") {
			var isClicked: Bool?
			searchBar.reactive.searchButtonClicked
				.observeValues { isClicked = true }

			expect(isClicked).to(beNil())
			expect(receiver.searchButtonClickedCounter) == 0

			searchBar.delegate!.searchBarSearchButtonClicked!(searchBar)
			expect(isClicked) == true
			expect(receiver.searchButtonClickedCounter) == 1
		}


		it("should notify when the bookmark button is clicked") {
			var isClicked: Bool?
			searchBar.reactive.bookmarkButtonClicked
				.observeValues { isClicked = true }

			expect(isClicked).to(beNil())
			expect(receiver.bookmarkButtonClickedCounter) == 0

			searchBar.delegate!.searchBarBookmarkButtonClicked!(searchBar)
			expect(isClicked) == true
			expect(receiver.bookmarkButtonClickedCounter) == 1
		}


		it("should notify when the results list button is clicked") {
			var isClicked: Bool?
			searchBar.reactive.resultsListButtonClicked
				.observeValues { isClicked = true }

			expect(isClicked).to(beNil())
			expect(receiver.resultsListButtonClickedCounter) == 0

			searchBar.delegate!.searchBarResultsListButtonClicked!(searchBar)
			expect(isClicked) == true
			expect(receiver.resultsListButtonClickedCounter) == 1
		}


		it("should notify when started editing") {
			var didBegin: Bool?
			searchBar.reactive.textDidBeginEditing
				.observeValues { didBegin = true }

			expect(didBegin).to(beNil())
			expect(receiver.beginEditingCounter) == 0

			searchBar.delegate!.searchBarTextDidBeginEditing!(searchBar)
			expect(didBegin) == true
			expect(receiver.beginEditingCounter) == 1
		}


		it("should notify when ended editing") {
			var didEnd: Bool?
			searchBar.reactive.textDidEndEditing
				.observeValues { didEnd = true }

			expect(didEnd).to(beNil())
			expect(receiver.endEditingTexts.isEmpty) == true

			searchBar.delegate!.searchBarTextDidEndEditing!(searchBar)
			expect(didEnd) == true
			expect(receiver.endEditingTexts.count) == 1
		}


		it("should accept changes from bindings to its hidden state of the cancel button") {
			searchBar.showsCancelButton = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			searchBar.reactive.showsCancelButton <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(searchBar.showsCancelButton) == true

			observer.send(value: false)
			expect(searchBar.showsCancelButton) == false
		}
	}
}

class SearchBarDelegateReceiver: NSObject, UISearchBarDelegate {
	var texts: [String] = []
	var beginEditingCounter = 0
	var endEditingTexts: [String] = []
	var searchButtonClickedCounter = 0
	var cancelButtonClickedCounter = 0
	var bookmarkButtonClickedCounter = 0
	var resultsListButtonClickedCounter = 0
	var selectedScopeButtonIndices: [Int] = []

	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchButtonClickedCounter += 1
	}

	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		texts.append(searchText)
	}

	func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		beginEditingCounter += 1
	}

	func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
		endEditingTexts.append(searchBar.text ?? "")
	}
	
	func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		cancelButtonClickedCounter += 1
	}

	func searchBarResultsListButtonClicked(_ searchBar: UISearchBar) {
		resultsListButtonClickedCounter += 1
	}

	func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
		bookmarkButtonClickedCounter += 1
	}

	func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		selectedScopeButtonIndices.append(selectedScope)
	}
}
