import Foundation
import enum Result.NoError

/// Models types that can be represented in Objective-C (i.e., reference
/// types, including generic types when boxed via `AnyObject`).
private protocol ObjectiveCRepresentable {
	associatedtype Value
	func extractValue(fromRepresentation representation: AnyObject) -> Value
	func represent(value value: Value) -> AnyObject
}

/// Wraps a `dynamic` property, or one defined in Objective-C, using Key-Value
/// Coding and Key-Value Observing.
///
/// Use this class only as a last resort! `MutableProperty` is generally better
/// unless KVC/KVO is required by the API you're using (for example,
/// `NSOperation`).
public final class DynamicProperty<Value>: MutablePropertyType {
	private weak var object: NSObject?
	private let keyPath: String
	private let representation: AnyRepresentation<Value>

	private var property: MutableProperty<Value?>?

	/// The current value of the property, as read and written using Key-Value
	/// Coding.
	public var value: Value? {
		get {
			return object?.valueForKeyPath(keyPath).map(representation.extractValue(fromRepresentation:))
		}

		set(newValue) {
			object?.setValue(newValue.map(representation.represent(value:)), forKeyPath: keyPath)
		}
	}

	/// A producer that will create a Key-Value Observer for the given object,
	/// send its initial value then all changes over time, and then complete
	/// when the observed object has deallocated.
	///
	/// By definition, this only works if the object given to init() is
	/// KVO-compliant. Most UI controls are not!
	public var producer: SignalProducer<Value?, NoError> {
		return property?.producer ?? .empty
	}

	public var signal: Signal<Value?, NoError> {
		return property?.signal ?? .empty
	}

	/// Initializes a property that will observe and set the given key path of
	/// the given object. `object` must support weak references!
	private init<Representatable: ObjectiveCRepresentable where Representatable.Value == Value>(object: NSObject?, keyPath: String, representable: Representatable) {
		self.object = object
		self.keyPath = keyPath
		self.property = MutableProperty(nil)
		self.representation = AnyRepresentation(representable)

		/// DynamicProperty stay alive as long as object is alive.
		/// This is made possible by strong reference cycles.

		object?.rac_valuesForKeyPath(keyPath, observer: nil)?
			.toSignalProducer()
			.start { event in
				switch event {
				case let .Next(newValue):
					self.property?.value = newValue.map(self.representation.extractValue(fromRepresentation:))
				case let .Failed(error):
					fatalError("Received unexpected error from KVO signal: \(error)")
				case .Interrupted, .Completed:
					self.property = nil
				}
			}
	}
}

extension DynamicProperty where Value: _ObjectiveCBridgeable {
	/// Initializes a property that will observe and set the given key path of
	/// the given object, where `Value` is a value type that is bridgeable
	/// to Objective-C.
	///
	/// `object` must support weak references!
	public convenience init(object: NSObject, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: BridgeableRepresentation())
	}
}

extension DynamicProperty where Value: AnyObject {
	/// Initializes a property that will observe and set the given key path of
	/// the given object, where `Value` is a reference type that can be
	/// represented directly in Objective-C via `AnyObject`.
	///
	/// `object` must support weak references!
	public convenience init(object: NSObject, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: DirectRepresentation())
	}
}

/// Represents values in Objective-C directly, via `AnyObject`.
private struct DirectRepresentation<Value: AnyObject>: ObjectiveCRepresentable {
	func extractValue(fromRepresentation representation: AnyObject) -> Value {
		return representation as! Value
	}

	func represent(value value: Value) -> AnyObject {
		return value
	}
}

/// Represents values in Objective-C indirectly, via bridging.
private struct BridgeableRepresentation<Value: _ObjectiveCBridgeable>: ObjectiveCRepresentable {
	func extractValue(fromRepresentation representation: AnyObject) -> Value {
		let object = representation as! Value._ObjectiveCType
		var result: Value?
		Value._forceBridgeFromObjectiveC(object, result: &result)
		return result!
	}

	func represent(value value: Value) -> AnyObject {
		return value._bridgeToObjectiveC()
	}
}

/// A type-erased wrapper for generic types representable in Objective-C.
private struct AnyRepresentation<Value>: ObjectiveCRepresentable {
	private let extract: AnyObject -> Value
	private let represent: Value -> AnyObject

	init<Base: ObjectiveCRepresentable where Base.Value == Value>(_ base: Base) {
		self.extract = { base.extractValue(fromRepresentation: $0) }
		self.represent = { base.represent(value: $0) }
	}

	func extractValue(fromRepresentation representation: AnyObject) -> Value {
		return extract(representation)
	}

	func represent(value value: Value) -> AnyObject {
		return represent(value)
	}
}
