import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import Result
import UIKit

final class UITableViewSpec: QuickSpec {
	override func spec() {
		var tableView: TestTableView!

		beforeEach {
			tableView = TestTableView()
		}

		describe("reloadData") {
			var bindingSignal: Signal<(), NoError>!
			var bindingObserver: Signal<(), NoError>.Observer!

			var reloadDataCount = 0

			beforeEach {
				let (signal, observer) = Signal<(), NoError>.pipe()
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
	let reloadDataSignal: Signal<(), NoError>
	private let reloadDataObserver: Signal<(), NoError>.Observer

	override init(frame: CGRect, style: UITableViewStyle) {
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
