import Quick
import Nimble
import Result
import ReactiveSwift
import ReactiveCocoa
import AppKit

class ReusableComponentsSpec: QuickSpec {
	override func spec() {
		describe("NSTableCellView") {
			it("should send a `value` event when `prepareForReuse` is triggered") {
				let cell = NSTableCellView()

				var isTriggered = false
				cell.reactive.prepareForReuse.observeValues {
					isTriggered = true
				}

				expect(isTriggered) == false

				cell.prepareForReuse()
				expect(isTriggered) == true
			}
		}

		if #available(macOS 10.11, *) {
			describe("NSCollectionViewItem") {
				it("should send a `value` event when `prepareForReuse` is triggered") {
					let item = TestViewItem()

					var isTriggered = false
					item.reactive.prepareForReuse.observeValues {
						isTriggered = true
					}

					expect(isTriggered) == false

					item.prepareForReuse()
					expect(isTriggered) == true
				}
			}
		}
	}
}

private class TestViewItem: NSCollectionViewItem {
	override func loadView() {
		view = NSView()
	}
}
