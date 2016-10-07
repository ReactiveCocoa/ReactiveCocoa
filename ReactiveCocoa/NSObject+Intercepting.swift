import Foundation
import ReactiveSwift
import enum Result.NoError
import ReactiveCocoaPrivate

extension Reactive where Base: NSObject {
	/// Create a signal which sends a `next` event at the end of every invocation
	/// of `selector` on the object.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns:
	///   A trigger signal.
	public func trigger(for selector: Selector) -> Signal<(), NoError> {
		return signal(for: selector) { observer in
			return { _ in observer.send(value: ()) }
		}
	}

	/// Create a signal which sends a `next` event at the end of every invocation
	/// of `selector` on the object.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///   - setup: The setup closure of how received events in the runtime are
	///            piped to the returned signal.
	///
	/// - returns:
	///   A trigger signal.
	private func signal<U>(for selector: Selector, setup: (Observer<U, NoError>) -> rac_receiver_t) -> Signal<U, NoError> {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		let map = associatedValue { _ in NSMutableDictionary() }

		let selectorName = String(describing: selector) as NSString
		if let signal = map.object(forKey: selectorName) as? Signal<U, NoError> {
			return signal
		}

		let (signal, observer) = Signal<U, NoError>.pipe()
		let action = setup(observer)
		let isSuccessful = RACRegisterBlockForSelector(base, selector, nil, action)
		assert(isSuccessful)

		lifetime.ended.observeCompleted(observer.sendCompleted)
		map.setObject(signal, forKey: selectorName)

		return signal
	}
}

private var mapKey = 0
