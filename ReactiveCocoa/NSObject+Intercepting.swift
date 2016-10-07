import Foundation
import ReactiveSwift
import enum Result.NoError
import ReactiveCocoaPrivate

extension Reactive where Base: NSObject {
	public func trigger(for selector: Selector) -> Signal<(), NoError> {
		return signal(for: selector) { observer in
			return { _ in observer.send(value: ()) }
		}
	}

	private func signal<U>(for selector: Selector, action: (Observer<U, NoError>) -> rac_receiver_t) -> Signal<U, NoError> {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		let map = associatedValue { _ in NSMutableDictionary() }

		let selectorName = String(describing: selector) as NSString
		if let signal = map.object(forKey: selectorName) as? Signal<U, NoError> {
			return signal
		}

		let (signal, observer) = Signal<U, NoError>.pipe()
		let action = action(observer)
		let isSuccessful = RACRegisterBlockForSelector(base, selector, nil, action)
		assert(isSuccessful)

		lifetime.ended.observeCompleted(observer.sendCompleted)
		map.setObject(signal, forKey: selectorName)

		return signal
	}
}

private var mapKey = 0
