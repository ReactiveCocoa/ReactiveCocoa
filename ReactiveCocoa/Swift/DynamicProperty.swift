import Foundation
import enum Result.NoError

/// Models types that can be represented in Objective-C (i.e., reference
/// types, including generic types when boxed via `AnyObject`).
private protocol ObjectiveCRepresentable {
	associatedtype Value
	static func extract(from representation: Any?) -> Value
	static func represent(_ value: Value) -> Any?
}

/// A lens to a `dynamic` property, or one defined in Objective-C, using Key-Value
/// Coding and Key-Value Observing.
///
/// - important: `DynamicProperty` retains its lensing object. Moreover,
///              `DynamicProperty` merely passes through the lifetime of its
///              lensing object. Therefore, all bindings targeting a
///               `DynamicProperty` would not be solely teared down by its
///              deinitialization.
///
/// - warning: Use this class only as a last resort. For just observations to
///            KVO-compliant key paths, use `NSObject.values(forKeyPath:)`.
///            `MutableProperty` is generally better unless KVC/KVO is
///            required by the API you're using (for example, `NSOperation`).
public final class DynamicProperty<Value>: MutablePropertyProtocol {
	private let object: NSObject
	private let keyPath: String

	private let extractValue: (_ from: Any?) -> Value
	private let represent: (Value) -> Any?

	/// The current value of the property.
	public var value: Value {
		get {
			return extractValue(object.value(forKeyPath: keyPath))
		}

		set(newValue) {
			object.setValue(represent(newValue), forKeyPath: keyPath)
		}
	}

	/// The lifetime of the property.
	public var lifetime: Lifetime {
		return object.rac_lifetime
	}

	/// A producer that send the initial value then all changes over time of the
	/// property, and then complete when its lensing object deinitializes.
	///
	/// - important: The lensing key path must be KVO compliant.
	public var producer: SignalProducer<Value, NoError> {
		return object.values(forKeyPath: keyPath).map(extractValue)
	}

	public lazy var signal: Signal<Value, NoError> = { [unowned self] in
		var signal: Signal<DynamicProperty.Value, NoError>!
		self.producer.startWithSignal { innerSignal, _ in signal = innerSignal }
		return signal
	}()

	/// Initializes a property that acts as a lens to the given key path of
	/// the given object, using the supplied representation.
	///
	/// - parameters:
	///   - object: An object to be lensed.
	///   - keyPath: Key path to lense on the object.
	///   - representable: A representation that bridges the values across the
	///                    language boundary.
	fileprivate init<Representatable: ObjectiveCRepresentable>(
		object: NSObject,
		keyPath: String,
		representable: Representatable.Type
	)
		where Representatable.Value == Value
	{
		self.object = object
		self.keyPath = keyPath

		self.extractValue = Representatable.extract(from:)
		self.represent = Representatable.represent
	}

	@discardableResult
	public static func <~ <Source: SignalProtocol>(target: DynamicProperty, signal: Source) -> Disposable? where Source.Value == Value, Source.Error == NoError {
		return signal
			.take(during: target.object.rac_lifetime)
			.observeNext { [weak object = target.object, represent = target.represent, keyPath = target.keyPath] value in
				object?.setValue(represent(value), forKeyPath: keyPath)
			}
	}
}

extension DynamicProperty where Value: _ObjectiveCBridgeable {
	/// Initializes a property that acts as a lens to the given key path of
	/// the given object, where `Value` is a value type that is bridgeable
	/// to Objective-C.
	///
	/// - parameters:
	///   - object: An object to be lensed.
	///   - keyPath: Key path to lense on the object.
	public convenience init(object: NSObject, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: BridgeableRepresentation.self)
	}
}

extension DynamicProperty where Value: AnyObject {
	/// Initializes a property that acts as a lens to the given key path of
	/// the given object, where `Value` is a reference type that can be
	/// represented directly in Objective-C via `AnyObject`.
	///
	/// - parameters:
	///   - object: An object to be lensed.
	///   - keyPath: Key path to lense on the object.
	public convenience init(object: NSObject, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: DirectRepresentation.self)
	}
}

extension DynamicProperty where Value: OptionalProtocol, Value.Wrapped: _ObjectiveCBridgeable {
	/// Initializes a property that acts as a lens to the given key path of
	/// the given object, where `Value` is a value type that is bridgeable
	/// to Objective-C.
	///
	/// - parameters:
	///   - object: An object to be lensed.
	///   - keyPath: Key path to lense on the object.
	public convenience init(object: NSObject, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: NullableBridgeableRepresentation.self)
	}
}

extension DynamicProperty where Value: OptionalProtocol, Value.Wrapped: AnyObject {
	/// Initializes a property that acts as a lens to the given key path of
	/// the given object, where `Value` is a reference type that can be
	/// represented directly in Objective-C via `AnyObject`.
	///
	/// - parameters:
	///   - object: An object to be lensed.
	///   - keyPath: Key path to lense on the object.
	public convenience init(object: NSObject, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: NullableDirectRepresentation.self)
	}
}

/// Represents values in Objective-C directly, via `AnyObject`.
private struct DirectRepresentation<Value: AnyObject>: ObjectiveCRepresentable {
	static func extract(from representation: Any?) -> Value {
		return representation as! Value
	}

	static func represent(_ value: Value) -> Any? {
		return value
	}
}

/// Represents values in Objective-C indirectly, via bridging.
private struct BridgeableRepresentation<Value: _ObjectiveCBridgeable>: ObjectiveCRepresentable {
	static func extract(from representation: Any?) -> Value {
		let object = representation as! Value._ObjectiveCType
		var result: Value?
		Value._forceBridgeFromObjectiveC(object, result: &result)
		return result!
	}

	static func represent(_ value: Value) -> Any? {
		return value._bridgeToObjectiveC()
	}
}

/// Represents nullable values in Objective-C directly, via `AnyObject`.
private struct NullableDirectRepresentation<Value: OptionalProtocol>: ObjectiveCRepresentable where Value.Wrapped: AnyObject {
	static func extract(from representation: Any?) -> Value {
		return representation as! Value
	}

	static func represent(_ value: Value) -> Any? {
		return value.optional
	}
}

/// Represents nullable values in Objective-C indirectly, via bridging.
private struct NullableBridgeableRepresentation<Value: OptionalProtocol>: ObjectiveCRepresentable where Value.Wrapped: _ObjectiveCBridgeable {
	static func extract(from representation: Any?) -> Value {
		let object = representation as? Value.Wrapped._ObjectiveCType
		return Value(reconstructing: object.map { value in
			var result: Value.Wrapped?
			Value.Wrapped._forceBridgeFromObjectiveC(value, result: &result)
			return result!
		})
	}

	static func represent(_ value: Value) -> Any? {
		return value.optional.map { $0._bridgeToObjectiveC() }
	}
}
