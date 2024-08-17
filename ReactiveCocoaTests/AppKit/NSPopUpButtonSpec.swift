#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import AppKit

final class NSPopUpButtonSpec: QuickSpec {
	override func spec() {
		let testTitles = (0..<100).map { $0.description }

		// Creates a temporary test subject, runs the specified testing block that receives the subject,
		// and checks if the subject is released.
		func test(_ subject: (NSPopUpButton) -> Void) {
			weak var reference: AnyObject?
			autoreleasepool {
				let window = NSWindow()
				let button = NSPopUpButton(frame: .zero)
				for (i, title) in testTitles.enumerated() {
					let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
					item.tag = 1000 + i
					button.menu?.addItem(item)
				}
				reference = button
				window.contentView?.addSubview(button)
				subject(button)
				button.removeFromSuperview()
			}

			expect(reference).to(beNil())
		}

		it("should emit selected index changes") {
			test { button in
				var values = [Int]()
				button.reactive.selectedIndexes.observeValues { values.append($0) }
		
				button.menu?.performActionForItem(at: 1)
				button.menu?.performActionForItem(at: 99)
			
				expect(values) == [1, 99]
			}
		}

		it("should emit selected title changes") {
			test { button in
				var values = [String]()
				button.reactive.selectedTitles.observeValues { values.append($0) }
			
				button.menu?.performActionForItem(at: 1)
				button.menu?.performActionForItem(at: 99)
				
				expect(values) == ["1", "99"]
			}
		}

		it("should accept changes from its bindings to its index values") {
			test { button in
				let (signal, observer) = Signal<Int?, Never>.pipe()
				button.reactive.selectedIndex <~ SignalProducer(signal)
				
				observer.send(value: 1)
				expect(button.indexOfSelectedItem) == 1
				
				observer.send(value: 99)
				expect(button.indexOfSelectedItem) == 99
				
				observer.send(value: nil)
				expect(button.indexOfSelectedItem) == -1
				expect(button.selectedItem?.title).to(beNil())
			}
		}

		it("should accept changes from its bindings to its title values") {
			test { button in
				let (signal, observer) = Signal<String?, Never>.pipe()
				button.reactive.selectedTitle <~ SignalProducer(signal)
				
				observer.send(value: "1")
				expect(button.selectedItem?.title) == "1"
				
				observer.send(value: "99")
				expect(button.selectedItem?.title) == "99"
				
				observer.send(value: nil)
				expect(button.selectedItem?.title).to(beNil())
				expect(button.indexOfSelectedItem) == -1
			}
		}

		it("should emit selected item changes") {
			test { button in
				var values = [NSMenuItem]()
				button.reactive.selectedItems.observeValues { values.append($0) }

				button.menu?.performActionForItem(at: 1)
				button.menu?.performActionForItem(at: 99)

				let titles = values.map { $0.title }
				expect(titles) == ["1", "99"]
			}
		}

		it("should emit selected tag changes") {
			test { button in
				var values = [Int]()
				button.reactive.selectedTags.observeValues { values.append($0) }

				button.menu?.performActionForItem(at: 1)
				button.menu?.performActionForItem(at: 99)

				expect(values) == [1001, 1099]
			}
		}

		it("should accept changes from its bindings to its tag values") {
			test { button in
				let (signal, observer) = Signal<Int, Never>.pipe()
				button.reactive.selectedTag <~ SignalProducer(signal)

				observer.send(value: 1001)
				expect(button.selectedItem?.tag) == 1001
				expect(button.indexOfSelectedItem) == 1

				observer.send(value: 1099)
				expect(button.selectedItem?.tag) == 1099
				expect(button.indexOfSelectedItem) == 99

				observer.send(value: 1042)
				expect(button.selectedItem?.tag) == 1042
				expect(button.indexOfSelectedItem) == 42

				// Sending an invalid tag number doesn't change the selection
				observer.send(value: testTitles.count + 1)
				expect(button.selectedItem?.tag) == 1042
				expect(button.indexOfSelectedItem) == 42
			}
		}
	}
}
#endif
