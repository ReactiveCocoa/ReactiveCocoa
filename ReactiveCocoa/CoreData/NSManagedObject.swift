import CoreData
import ReactiveSwift
import enum Result.NoError

extension ReactiveProtocol where Base: NSManagedObject {
	/// Create a producer which sends the current value and all the subsequent
	/// changes of the key path, but ignore `nil`s emitted due to the managed
	/// object being turned into a fault, or being deleted.
	///
	/// The producer completes when the object deinitializes.
	///
	/// - note: The resulting producer can be safety transformed as a strong-typed
	///         non-optional producer. To opt out of the filtering, coerce the
	///         object as `NSObject`.
	///
	/// - note: Starting the resulting producer would fault in the managed object.
	///
	/// - parameters:
	///   - keyPath: The key path of the property to be observed.
	///
	/// - returns:
	///   A producer emitting values of the the key path.
	public func values(forKeyPath keyPath: String) -> SignalProducer<Any?, NoError> {
		return SignalProducer { observer, disposable in
			self.base.willAccessValue(forKey: nil)
			defer { self.base.didAccessValue(forKey: nil) }

			disposable += (self.base as NSObject).reactive
				.values(forKeyPath: keyPath)
				.startWithValues { [weak base = self.base] value in
					if let base = base, base.faultingState == 0 && !base.isDeleted {
						observer.send(value: value)
					}
				}
		}
	}
}

extension DynamicProperty {
	public convenience init<Object: NSManagedObject>(object: Object, keyPath: String) {
		self.init(object: object, keyPath: keyPath) { ($0 as! NSManagedObject).reactive.values(forKeyPath: keyPath) }
	}
}
