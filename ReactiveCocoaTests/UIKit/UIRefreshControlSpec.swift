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

		it("should accept changes from bindings to its attributed title state") {
			let (pipeSignal, observer) = Signal<NSAttributedString?, NoError>.pipe()
			refreshControl.reactive.attributedTitle <~ SignalProducer(signal: pipeSignal)

			let string = NSAttributedString(string: "test")

			observer.send(value: nil)
			expect(refreshControl.attributedTitle).to(beNil())

			observer.send(value: string)
			expect(refreshControl.attributedTitle) == string

			observer.send(value: nil)
			expect(refreshControl.attributedTitle).to(beNil())
		}

		it("should execute the `refreshed` action upon receiving a `valueChanged` action message.") {
			refreshControl.isEnabled = true
			refreshControl.isUserInteractionEnabled = true

			let refreshed = MutableProperty(false)
			let action = Action<(), Bool, NoError> { _ in
				SignalProducer(value: true)
			}

			refreshed <~ SignalProducer(signal: action.values)

			refreshControl.reactive.refresh = CocoaAction(action)
			expect(refreshed.value) == false

			refreshControl.sendActions(for: .valueChanged)
			expect(refreshed.value) == true
		}
	}
}
