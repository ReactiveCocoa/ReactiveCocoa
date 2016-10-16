import Quick
import Nimble
import Result
import ReactiveSwift
import ReactiveCocoa
import AppKit

class ReusableComponentsSpec: QuickSpec {
	override func spec() {
		describe("NSTableCellView") {
			let cell = NSTableCellView()

			var isTriggered = false
			cell.reactive.prepareForReuse.observeValues {
				isTriggered = true
			}

			expect(isTriggered) == false

			cell.prepareForReuse()
			expect(isTriggered) == true
		}

		describe("NSCollectionViewItem") {
			let cell = NSCollectionViewItem()

			var isTriggered = false
			cell.reactive.prepareForReuse.observeValues {
				isTriggered = true
			}

			expect(isTriggered) == false

			cell.prepareForReuse()
			expect(isTriggered) == true
		}
	}
}
