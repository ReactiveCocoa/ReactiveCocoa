import Foundation
import ReactiveSwift
import enum Result.NoError

extension Reactive where Base: NSObject {
	/// Create a signal which sends a `next` event at the end of every invocation
	/// of `selector` on the object.
	///
	/// `trigger(for:from:)` can be used to intercept optional protocol
	/// requirements by supplying the protocol as `protocol`. The instance need
	/// not have a concrete implementation of the requirement.
	///
	/// However, as Cocoa classes usually cache information about delegate
	/// conformances, trigger signals for optional, unbacked protocol requirements
	/// should be set up before the instance is assigned as the corresponding
	/// delegate.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///   - protocol: The protocol of the selector, or `nil` if the selector does
	///               not belong to any protocol.
	///
	/// - returns:
	///   A trigger signal.
	public func trigger(for selector: Selector, from protocol: Protocol? = nil) -> Signal<(), NoError> {
		return base.synchronized {
			let map = associatedValue { _ in NSMutableDictionary() }

			let selectorName = String(describing: selector) as NSString
			if let signal = map.object(forKey: selectorName) as! Signal<(), NoError>? {
				return signal
			}

			let (signal, observer) = Signal<(), NoError>.pipe()
			let isSuccessful = base._rac_setupInvocationObservation(for: selector,
			                                                        protocol: `protocol`,
			                                                        receiver: { _ in observer.send(value: ()) })
			precondition(isSuccessful)

			lifetime.ended.observeCompleted(observer.sendCompleted)
			map.setObject(signal, forKey: selectorName)

			return signal
		}
	}
}
