import Foundation
import ReactiveSwift
import enum Result.NoError

/// Models types that can be represented in Objective-C (i.e., reference
/// types, including generic types when boxed via `AnyObject`).
private protocol ObjectiveCRepresentable {
	associatedtype Value
	static func extract(from representation: Any) -> Value
	static func represent(_ value: Value) -> Any
}

/// Wraps a `dynamic` property, or one defined in Objective-C, using Key-Value
/// Coding and Key-Value Observing.
///
/// Use this class only as a last resort! `MutableProperty` is generally better
/// unless KVC/KVO is required by the API you're using (for example,
/// `NSOperation`).
public final class DynamicProperty<Value>: MutablePropertyProtocol {
	private weak var object: NSObject?
	private let keyPath: String

	private let extractValue: (_ from: Any) -> Value
	private let represent: (Value) -> Any

	private var property: MutableProperty<Value?>?

	/// The current value of the property, as read and written using Key-Value
	/// Coding.
	public var value: Value? {
		get {
			return object?.value(forKeyPath: keyPath).map(extractValue)
		}

		set(newValue) {
			object?.setValue(newValue.map(represent), forKeyPath: keyPath)
		}
	}

	/// The lifetime of the property.
	public var lifetime: Lifetime {
		return object?.rac_lifetime ?? .empty
	}

	/// A producer that will create a Key-Value Observer for the given object,
	/// send its initial value then all changes over time, and then complete
	/// when the observed object has deallocated.
	///
	/// - important: This only works if the object given to init() is KVO-compliant.
	///              Most UI controls are not!
	public var producer: SignalProducer<Value?, NoError> {
		return (object.map { $0.values(forKeyPath: keyPath) } ?? .empty)
			.map { [extractValue = self.extractValue] in $0.map(extractValue) }
	}

	public lazy var signal: Signal<Value?, NoError> = { [unowned self] in
		var signal: Signal<DynamicProperty.Value, NoError>!
		self.producer.startWithSignal { innerSignal, _ in signal = innerSignal }
		return signal
	}()

	/// Initializes a property that will observe and set the given key path of
	/// the given object, using the supplied representation.
	///
	/// - important: `object` must support weak references!
	///
	/// - parameters:
	///   - object: An object to be observed.
	///   - keyPath: Key path to observe on the object.
	///   - representable: A representation that bridges the values across the
	///                    language boundary.
	fileprivate init<Representatable: ObjectiveCRepresentable>(
		object: NSObject?,
		keyPath: String,
		representable: Representatable.Type
	)
		where Representatable.Value == Value
	{
		self.object = object
		self.keyPath = keyPath

		self.extractValue = Representatable.extract(from:)
		self.represent = Representatable.represent

		/// A DynamicProperty will stay alive as long as its object is alive.
		/// This is made possible by strong reference cycles.
		_ = object?.rac_lifetime.ended.observeCompleted { _ = self }
	}
}

extension DynamicProperty where Value: _ObjectiveCBridgeable {
	/// Initializes a property that will observe and set the given key path of
	/// the given object, where `Value` is a value type that is bridgeable
	/// to Objective-C.
	///
	/// - important: `object` must support weak references!
	///
	/// - parameters:
	///   - object: An object to be observed.
	///   - keyPath: Key path to observe on the object.
	public convenience init(object: NSObject?, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: BridgeableRepresentation.self)
	}
}

extension DynamicProperty where Value: AnyObject {
	/// Initializes a property that will observe and set the given key path of
	/// the given object, where `Value` is a reference type that can be
	/// represented directly in Objective-C via `AnyObject`.
	///
	/// - important: `object` must support weak references!
	///
	/// - parameters:
	///   - object: An object to be observed.
	///   - keyPath: Key path to observe on the object.
	public convenience init(object: NSObject?, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: DirectRepresentation.self)
	}
}

/// Represents values in Objective-C directly, via `AnyObject`.
private struct DirectRepresentation<Value: AnyObject>: ObjectiveCRepresentable {
	static func extract(from representation: Any) -> Value {
		return representation as! Value
	}

	static func represent(_ value: Value) -> Any {
		return value
	}
}

/// Represents values in Objective-C indirectly, via bridging.
private struct BridgeableRepresentation<Value: _ObjectiveCBridgeable>: ObjectiveCRepresentable {
	static func extract(from representation: Any) -> Value {
		let object = representation as! Value._ObjectiveCType
		var result: Value?
		Value._forceBridgeFromObjectiveC(object, result: &result)
		return result!
	}

	static func represent(_ value: Value) -> Any {
		return value._bridgeToObjectiveC()
	}
}
