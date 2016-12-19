import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import Result
import UIKit

final class UICollectionViewSpec: QuickSpec {
	override func spec() {
		var collectionView: TestCollectionView!

		beforeEach {
			collectionView = TestCollectionView()
		}

		describe("reloadData") {
			var bindingSignal: Signal<(), NoError>!
			var bindingObserver: Signal<(), NoError>.Observer!

			var reloadDataCount = 0

			beforeEach {
				let (signal, observer) = Signal<(), NoError>.pipe()
				(bindingSignal, bindingObserver) = (signal, observer)

				reloadDataCount = 0

				collectionView.reloadDataSignal.observeValues {
					reloadDataCount += 1
				}
			}

			it("invokes reloadData whenever the bound signal sends a value") {
				collectionView.reactive.reloadData <~ bindingSignal

				bindingObserver.send(value: ())
				bindingObserver.send(value: ())

				expect(reloadDataCount) == 2
			}
		}
	}
}

private final class TestCollectionView: UICollectionView {
	let reloadDataSignal: Signal<(), NoError>
	private let reloadDataObserver: Signal<(), NoError>.Observer

	init() {
		(reloadDataSignal, reloadDataObserver) = Signal.pipe()
		super.init(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
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
