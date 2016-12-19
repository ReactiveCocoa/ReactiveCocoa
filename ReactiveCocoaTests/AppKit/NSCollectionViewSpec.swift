import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import Result
import AppKit

@available(macOS 10.11, *)
final class NSCollectionViewSpec: QuickSpec {
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

@available(macOS 10.11, *)
private final class TestCollectionView: NSCollectionView {
	let reloadDataSignal: Signal<(), NoError>
	private let reloadDataObserver: Signal<(), NoError>.Observer

	override init(frame: CGRect) {
		(reloadDataSignal, reloadDataObserver) = Signal.pipe()
		super.init(frame: frame)
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
