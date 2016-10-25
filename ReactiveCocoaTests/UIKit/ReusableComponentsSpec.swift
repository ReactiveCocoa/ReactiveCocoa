import Quick
import Nimble
import Result
import ReactiveSwift
import ReactiveCocoa
import UIKit

class ReusableComponentsSpec: QuickSpec {
	override func spec() {
		describe("UITableViewCell") {
			it("should send a `value` event when `prepareForReuse` is triggered") {
				let cell = UITableViewCell()

				var isTriggered = false
				cell.reactive.prepareForReuse.observeValues {
					isTriggered = true
				}

				expect(isTriggered) == false

				cell.prepareForReuse()
				expect(isTriggered) == true
			}
		}

		describe("UITableViewHeaderFooterView") {
			it("should send a `value` event when `prepareForReuse` is triggered") {
				let cell = UITableViewHeaderFooterView()

				var isTriggered = false
				cell.reactive.prepareForReuse.observeValues {
					isTriggered = true
				}

				expect(isTriggered) == false

				cell.prepareForReuse()
				expect(isTriggered) == true
			}
		}

		describe("UICollectionReusableView") {
			it("should send a `value` event when `prepareForReuse` is triggered") {
				let cell = UICollectionReusableView()

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
}
