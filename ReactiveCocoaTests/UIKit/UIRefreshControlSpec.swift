import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import Result

class UIRefreshControlSpec: QuickSpec {
	override func spec() {
		var refreshControl: UIRefreshControl!
		weak var _refreshControl: UIRefreshControl!

		beforeEach {
			refreshControl = UIRefreshControl()
			_refreshControl = refreshControl
		}

		afterEach {
			refreshControl = nil
			expect(_refreshControl).to(beNil())
		}

		it("should accept changes from bindings to its refreshing state") {
			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			refreshControl.reactive.isRefreshing <~ SignalProducer(signal: pipeSignal)

			observer.send(value: true)
			expect(refreshControl.isRefreshing) == true

			observer.send(value: false)
			expect(refreshControl.isRefreshing) == false
		}

		it("should emit user's changes for its value") {
			var count = 0

			refreshControl.reactive.refresh.observeValues {
				count += 1
			}

			expect(count) == 0
			refreshControl.sendActions(for: .valueChanged)
			expect(count) == 1
		}
	}
}
