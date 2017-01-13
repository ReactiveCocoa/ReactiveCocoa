import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import Result
import AppKit

final class NSPopUpButtonSpec: QuickSpec {
	override func spec() {
		describe("NSPopUpButton") {
			var button: NSPopUpButton!
			var window: NSWindow!
			weak var _button: NSButton?
			let testTitles = (0..<100).map { $0.description }
			
			beforeEach {
				window = NSWindow()
				button = NSPopUpButton(frame: .zero)
				_button = button
				button.addItems(withTitles: testTitles )
				window.contentView?.addSubview(button)
			}
			
			afterEach {
				autoreleasepool {
					button.removeFromSuperview()
					button = nil
				}
				expect(_button).to(beNil())
			}
			
			it("should emit selected index changes") {
				var values = [Int]()
				button.reactive.selectedIndexes.observeValues { values.append($0) }
		
				button.menu?.performActionForItem(at: 1)
				button.menu?.performActionForItem(at: 99)
			
				expect(values) == [1, 99]
			}
			
			it("should emit selected title changes") {
				var values = [String]()
				button.reactive.selectedTitles.observeValues { values.append($0) }
			
				button.menu?.performActionForItem(at: 1)
				button.menu?.performActionForItem(at: 99)
				
				expect(values) == ["1", "99"]
			}
			
			it("should accept changes from its bindings to its index values") {
				let (signal, observer) = Signal<Int?, NoError>.pipe()
				button.reactive.selectedIndex <~ SignalProducer(signal)
				
				observer.send(value: 1)
				expect(button.indexOfSelectedItem) == 1
				
				observer.send(value: 99)
				expect(button.indexOfSelectedItem) == 99
				
				observer.send(value: nil)
				expect(button.indexOfSelectedItem) == -1
				expect(button.selectedItem?.title).to(beNil())
			}
			
			it("should accept changes from its bindings to its title values") {
				let (signal, observer) = Signal<String?, NoError>.pipe()
				button.reactive.selectedTitle <~ SignalProducer(signal)
				
				observer.send(value: "1")
				expect(button.selectedItem?.title) == "1"
				
				observer.send(value: "99")
				expect(button.selectedItem?.title) == "99"
				
				observer.send(value: nil)
				expect(button.selectedItem?.title).to(beNil())
				expect(button.indexOfSelectedItem) == -1
			}

			it("should emit selected item changes") {
				var values = [NSMenuItem]()
				button.reactive.selectedItems.observeValues { values.append($0) }

				button.menu?.performActionForItem(at: 1)
				button.menu?.performActionForItem(at: 99)

				let titles = values.map { $0.title }
				expect(titles) == ["1", "99"]
			}
		}
	}
}
