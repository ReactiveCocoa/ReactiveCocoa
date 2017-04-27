import Foundation
import ReactiveSwift
import enum Result.NoError

/// A typed mutable property view to a certain key path of an Objective-C object using
/// Key-Value Coding and Key-Value Observing.
///
/// Bindings towards a `DynamicProperty` would be directed to the underlying Objective-C
/// object, and would not be affected by the deinitialization of the `DynamicProperty`.
public final class DynamicProperty<Value>: MutablePropertyProtocol {
	private weak var object: NSObject?
	private let keyPath: String
	private let cache: Property<Value>

	/// The current value of the property, as read and written using Key-Value
	/// Coding.
	public var value: Value {
		get { return cache.value }
		set { object?.setValue(newValue, forKeyPath: keyPath) }
	}

	/// The lifetime of the property.
	public var lifetime: Lifetime {
		return object?.reactive.lifetime ?? .empty
	}

	/// The binding target of the property.
	public var bindingTarget: BindingTarget<Value> {
		return BindingTarget(lifetime: lifetime) { [weak object, keyPath] value in
			object?.setValue(value, forKey: keyPath)
		}
	}

	/// A producer that will create a Key-Value Observer for the given object,
	/// send its initial value then all changes over time, and then complete
	/// when the observed object has deallocated.
	///
	/// - important: This only works if the object given to init() is KVO-compliant.
	///              Most UI controls are not!
	public var producer: SignalProducer<Value, NoError> {
		return cache.producer
	}

	public var signal: Signal<Value, NoError> {
		return cache.signal
	}

	/// Create a typed mutable view to the given key path of the given Objective-C object.	
	/// The generic type `Value` can be any Swift type, and will be bridged to Objective-C
	/// via `Any`.
	///
	/// - parameters:
	///   - object: The Objective-C object to be observed.
	///   - keyPath: The key path to observe.
	public init(object: NSObject, keyPath: String) {
		self.object = object
		self.keyPath = keyPath
		self.cache = Property(object: object, keyPath: keyPath)
	}
}
