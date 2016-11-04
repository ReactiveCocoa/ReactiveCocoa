import Foundation
import ReactiveSwift
import enum Result.NoError

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
		return base.synchronized {
			let map = associatedValue { _ in NSMutableDictionary() }

			let selectorName = String(describing: selector) as NSString
			if let signal = map.object(forKey: selectorName) as! Signal<(), NoError>? {
				return signal
			}

			let (signal, observer) = Signal<(), NoError>.pipe()
			let isSuccessful = base._rac_setupInvocationObservation(for: selector,
			                                                        protocol: nil,
			                                                        receiver: observer.send(value:))
			precondition(isSuccessful)

			lifetime.ended.observeCompleted(observer.sendCompleted)
			map.setObject(signal, forKey: selectorName)

			return signal
		}
	}
}
