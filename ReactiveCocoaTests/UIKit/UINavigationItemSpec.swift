import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UINavigationItemSpec: QuickSpec {
	override func spec() {
		var navigationItem: UINavigationItem!
		weak var _navigationItem: UINavigationItem?
		
		beforeEach {
			navigationItem = UINavigationItem(title: "initial")
			_navigationItem = navigationItem
		}
		
		afterEach {
			navigationItem = nil
			expect(_navigationItem).to(beNil())
		}
		
		it("should accept changes from bindings to its title value") {
			let firstChange = "first"
			let secondChange = "second"
			
			navigationItem.title = ""
			
			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			navigationItem.reactive.title <~ pipeSignal
			
			observer.send(value: firstChange)
			expect(navigationItem.title) == firstChange
			
			observer.send(value: secondChange)
			expect(navigationItem.title) == secondChange
			
			observer.send(value: nil)
			expect(navigationItem.title).to(beNil())
		}

		it("should accept changes from bindings to its titleView value") {
			let firstChange = UIView()
			firstChange.accessibilityIdentifier = "first"

			let secondChange = UIView()
			secondChange.accessibilityIdentifier = "second"

			navigationItem.titleView = nil

			let (pipeSignal, observer) = Signal<UIView?, NoError>.pipe()
			navigationItem.reactive.titleView <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.titleView) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.titleView) == secondChange

			observer.send(value: nil)
			expect(navigationItem.titleView).to(beNil())
		}
		
#if os(iOS)
		it("should accept changes from bindings to its prompt value") {
			let firstChange = "first"
			let secondChange = "second"

			navigationItem.prompt = ""

			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			navigationItem.reactive.prompt <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.prompt) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.prompt) == secondChange

			observer.send(value: nil)
			expect(navigationItem.prompt).to(beNil())
		}

		it("should accept changes from bindings to its backBarButtonItem value") {
			let firstChange = UIBarButtonItem(title: "first", style: .plain, target: nil, action: nil)
			let secondChange = UIBarButtonItem(title: "second", style: .plain, target: nil, action: nil)

			navigationItem.backBarButtonItem = nil

			let (pipeSignal, observer) = Signal<UIBarButtonItem?, NoError>.pipe()
			navigationItem.reactive.backBarButtonItem <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.backBarButtonItem) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.backBarButtonItem) == secondChange

			observer.send(value: nil)
			expect(navigationItem.backBarButtonItem).to(beNil())
		}

		it("should accept changes from bindings to its hidesBackButton value") {
			let firstChange = true
			let secondChange = false

			navigationItem.hidesBackButton = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			navigationItem.reactive.hidesBackButton <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.hidesBackButton) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.hidesBackButton) == secondChange
		}
#endif

		it("should accept changes from bindings to its leftBarButtonItems value") {
			let firstChange = [
				UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil),
				UIBarButtonItem(title: "first", style: .plain, target: nil, action: nil)
			]

			let secondChange = [
				UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil),
				UIBarButtonItem(title: "second", style: .plain, target: nil, action: nil)
			]

			navigationItem.leftBarButtonItems = nil

			let (pipeSignal, observer) = Signal<[UIBarButtonItem]?, NoError>.pipe()
			navigationItem.reactive.leftBarButtonItems <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.leftBarButtonItems) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.leftBarButtonItems) == secondChange

			observer.send(value: nil)
			expect(navigationItem.leftBarButtonItems).to(beNil())
		}

		it("should accept changes from bindings to its rightBarButtonItems value") {
			let firstChange = [
				UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil),
				UIBarButtonItem(title: "first", style: .plain, target: nil, action: nil)
			]

			let secondChange = [
				UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil),
				UIBarButtonItem(title: "second", style: .plain, target: nil, action: nil)
			]

			navigationItem.rightBarButtonItems = nil

			let (pipeSignal, observer) = Signal<[UIBarButtonItem]?, NoError>.pipe()
			navigationItem.reactive.rightBarButtonItems <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.rightBarButtonItems) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.rightBarButtonItems) == secondChange

			observer.send(value: nil)
			expect(navigationItem.rightBarButtonItems).to(beNil())
		}

		it("should accept changes from bindings to its leftBarButtonItem value") {
			let firstChange = UIBarButtonItem(title: "first", style: .plain, target: nil, action: nil)
			let secondChange = UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil)

			navigationItem.leftBarButtonItem = nil

			let (pipeSignal, observer) = Signal<UIBarButtonItem?, NoError>.pipe()
			navigationItem.reactive.leftBarButtonItem <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.leftBarButtonItem) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.leftBarButtonItem) == secondChange

			observer.send(value: nil)
			expect(navigationItem.leftBarButtonItem).to(beNil())
		}

		it("should accept changes from bindings to its rightBarButtonItem value") {
			let firstChange = UIBarButtonItem(title: "first", style: .plain, target: nil, action: nil)
			let secondChange = UIBarButtonItem(title: "second", style: .plain, target: nil, action: nil)

			navigationItem.rightBarButtonItem = nil

			let (pipeSignal, observer) = Signal<UIBarButtonItem?, NoError>.pipe()
			navigationItem.reactive.rightBarButtonItem <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.rightBarButtonItem) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.rightBarButtonItem) == secondChange

			observer.send(value: nil)
			expect(navigationItem.rightBarButtonItem).to(beNil())
		}

#if os(iOS)
		it("should accept changes from bindings to its leftItemsSupplementBackButton value") {
			let firstChange = true
			let secondChange = false

			navigationItem.leftItemsSupplementBackButton = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			navigationItem.reactive.leftItemsSupplementBackButton <~ pipeSignal

			observer.send(value: firstChange)
			expect(navigationItem.leftItemsSupplementBackButton) == firstChange

			observer.send(value: secondChange)
			expect(navigationItem.leftItemsSupplementBackButton) == secondChange
		}

		if #available(iOS 11.0, *) {
			it("should accept changes from bindings to its largeTitleDisplayMode value") {
				let firstChange = UINavigationItem.LargeTitleDisplayMode.always
				let secondChange = UINavigationItem.LargeTitleDisplayMode.automatic

				navigationItem.largeTitleDisplayMode = .automatic

				let (pipeSignal, observer) = Signal<UINavigationItem.LargeTitleDisplayMode, NoError>.pipe()
				navigationItem.reactive.largeTitleDisplayMode <~ pipeSignal

				observer.send(value: firstChange)
				expect(navigationItem.largeTitleDisplayMode) == firstChange

				observer.send(value: secondChange)
				expect(navigationItem.largeTitleDisplayMode) == secondChange
			}

			it("should accept changes from bindings to its searchController value") {
				let firstChange = UISearchController()
				firstChange.view.accessibilityIdentifier = "firstChange"

				let secondChange = UISearchController()
				secondChange.view.accessibilityIdentifier = "firstChange"

				navigationItem.searchController = nil

				let (pipeSignal, observer) = Signal<UISearchController?, NoError>.pipe()
				navigationItem.reactive.searchController <~ pipeSignal

				observer.send(value: firstChange)
				expect(navigationItem.searchController) == firstChange

				observer.send(value: secondChange)
				expect(navigationItem.searchController) == secondChange

				observer.send(value: nil)
				expect(navigationItem.searchController).to(beNil())
			}

			it("should accept changes from bindings to its hidesSearchBarWhenScrolling value") {
				let firstChange = true
				let secondChange = false

				navigationItem.hidesSearchBarWhenScrolling = false

				let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
				navigationItem.reactive.hidesSearchBarWhenScrolling <~ pipeSignal

				observer.send(value: firstChange)
				expect(navigationItem.hidesSearchBarWhenScrolling) == firstChange

				observer.send(value: secondChange)
				expect(navigationItem.hidesSearchBarWhenScrolling) == secondChange
			}
		}
#endif
	}
}
