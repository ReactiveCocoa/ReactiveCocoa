#if canImport(UIKit)
import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble

final class UITableViewSpec: QuickSpec {
	override func spec() {
		var tableView: TestTableView!

		beforeEach {
			tableView = TestTableView()
		}

		describe("reloadData") {
			var bindingSignal: Signal<(), Never>!
			var bindingObserver: Signal<(), Never>.Observer!

			var reloadDataCount = 0

			beforeEach {
				let (signal, observer) = Signal<(), Never>.pipe()
				(bindingSignal, bindingObserver) = (signal, observer)

				reloadDataCount = 0

				tableView.reloadDataSignal.observeValues {
					reloadDataCount += 1
				}
			}

			it("invokes reloadData whenever the bound signal sends a value") {
				tableView.reactive.reloadData <~ bindingSignal

				bindingObserver.send(value: ())
				bindingObserver.send(value: ())

				expect(reloadDataCount) == 2
			}
		}
	}
}

private final class TestTableView: UITableView {
	let reloadDataSignal: Signal<(), Never>
	private let reloadDataObserver: Signal<(), Never>.Observer

	override init(frame: CGRect, style: UITableView.Style) {
		(reloadDataSignal, reloadDataObserver) = Signal.pipe()
		super.init(frame: frame, style: style)
	}

	required init?(coder aDecoder: NSCoder) {
		(reloadDataSignal, reloadDataObserver) = Signal.pipe()
		super.init(coder: aDecoder)
	}

	override func reloadData() {
		super.reloadData()
		reloadDataObserver.send(value: ())
	}
}
#endif
