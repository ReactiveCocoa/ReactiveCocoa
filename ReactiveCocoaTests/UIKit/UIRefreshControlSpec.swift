#if canImport(UIKit) && !os(tvOS)
import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble

class UIRefreshControlSpec: QuickSpec {
	override func spec() {

		// Creates a temporary test subject, runs the specified testing block that receives the subject,
		// and checks if the subject is released.
		func test(_ subject: (UIRefreshControl) -> Void) {
			weak var reference: UIRefreshControl?
			autoreleasepool {
				let window = UIWindow(frame: UIScreen.main.bounds)
				let container = UIScrollView()
				let control = UIRefreshControl()
				window.addSubview(container)
				container.refreshControl = control
				subject(control)
				container.refreshControl = nil
				container.removeFromSuperview()
			}
			// Something keeps retaining the reference for a short while after it gets released,
			// using `toEventually` ensures the tests are passing.
			expect(reference).toEventually(beNil())
		}

		it("should accept changes from bindings to its refreshing state") {
			test { refreshControl in
				let (pipeSignal, observer) = Signal<Bool, Never>.pipe()
				refreshControl.reactive.isRefreshing <~ SignalProducer(pipeSignal)

				observer.send(value: true)
				expect(refreshControl.isRefreshing) == true

				observer.send(value: false)
				expect(refreshControl.isRefreshing) == false
			}
		}

		it("should accept changes from bindings to its attributed title state") {
			test { refreshControl in
				let (pipeSignal, observer) = Signal<NSAttributedString?, Never>.pipe()
				refreshControl.reactive.attributedTitle <~ SignalProducer(pipeSignal)

				let string = NSAttributedString(string: "test")

				observer.send(value: nil)
				expect(refreshControl.attributedTitle).to(beNil())

				observer.send(value: string)
				expect(refreshControl.attributedTitle) == string

				observer.send(value: nil)
				expect(refreshControl.attributedTitle).to(beNil())
			}
		}

		it("should execute the `refresh` action upon receiving a `valueChanged` action message.") {
			test { refreshControl in
				refreshControl.isEnabled = true
				refreshControl.isUserInteractionEnabled = true

				let refreshed = MutableProperty(false)
				let action = Action<(), Bool, Never> { _ in
					SignalProducer(value: true)
				}

				refreshed <~ SignalProducer(action.values)

				refreshControl.reactive.refresh = CocoaAction(action)
				expect(refreshed.value) == false

				refreshControl.sendActions(for: .valueChanged)
				expect(refreshed.value) == true
			}
		}

		it("should set `isRefreshing` while `refresh` is executing.") {
			test { refreshControl in
				refreshControl.isEnabled = true
				refreshControl.isUserInteractionEnabled = true

				let action = Action<(), Bool, Never> { _ in
					SignalProducer(value: true).delay(1, on: QueueScheduler.main)
				}

				refreshControl.reactive.refresh = CocoaAction(action)
				expect(refreshControl.isRefreshing) == false

				refreshControl.sendActions(for: .valueChanged)
				expect(refreshControl.isRefreshing) == true

				expect(refreshControl.isRefreshing).toEventually(equal(false), timeout: .seconds(2))
			}
		}
	}
}
#endif
