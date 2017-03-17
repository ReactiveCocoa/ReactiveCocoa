import Foundation
import ReactiveSwift
import enum Result.NoError

/// Wraps a `dynamic` property, or one defined in Objective-C, using Key-Value
/// Coding and Key-Value Observing.
///
/// Use this class only as a last resort! `MutableProperty` is generally better
/// unless KVC/KVO is required by the API you're using (for example,
/// `NSOperation`).
public final class DynamicProperty<Value>: MutablePropertyProtocol {
	private weak var object: NSObject?
	private let keyPath: String

	/// The current value of the property, as read and written using Key-Value
	/// Coding.
	public var value: Value? {
		get {
			return object?.value(forKeyPath: keyPath) as! Value
		}

		set(newValue) {
			object?.setValue(newValue, forKeyPath: keyPath)
		}
	}

	/// The lifetime of the property.
	public var lifetime: Lifetime {
		return object?.reactive.lifetime ?? .empty
	}

	/// A producer that will create a Key-Value Observer for the given object,
	/// send its initial value then all changes over time, and then complete
	/// when the observed object has deallocated.
	///
	/// - important: This only works if the object given to init() is KVO-compliant.
	///              Most UI controls are not!
	public var producer: SignalProducer<Value?, NoError> {
		return (object.map { $0.reactive.producer(forKeyPath: keyPath) } ?? .empty)
			.map { $0 as! Value }
	}

	public private(set) lazy var signal: Signal<Value?, NoError> = {
		var signal: Signal<DynamicProperty.Value, NoError>!
		self.producer.startWithSignal { innerSignal, _ in signal = innerSignal }
		return signal
	}()

	/// Initializes a property that will observe and set the given key path of
	/// the given object. The generic type `Value` can be any Swift type, and will
	/// be bridged to Objective-C via `Any`.
	///
	/// - important: `object` must support weak references!
	///
	/// - parameters:
	///   - object: An object to be observed.
	///   - keyPath: Key path to observe on the object.
	public init(object: NSObject, keyPath: String) {
		self.object = object
		self.keyPath = keyPath

		/// A DynamicProperty will stay alive as long as its object is alive.
		/// This is made possible by strong reference cycles.
		_ = object.reactive.lifetime.ended.observeCompleted { _ = self }
	}
}
