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

/// A lens to a `dynamic` property, or one defined in Objective-C, using Key-Value
/// Coding and Key-Value Observing.
///
/// - important: The `DynamicProperty` weakly references the underlying object.
///              Moreover, bindings targeting a `DynamicProperty` respect the
///              lifetime of the underlying object.
///
/// - warning: Use this class only as a last resort. For just observations to
///            KVO-compliant key paths, use `NSObject.values(forKeyPath:)`.
///            `MutableProperty` is generally better unless KVC/KVO is
///            required by the API you're using (for example, `NSOperation`).
public final class DynamicProperty<Value>: MutablePropertyProtocol {
	private weak var object: NSObject?
	private let keyPath: String

	private let extractValue: (_ from: Any) -> Value
	private let represent: (Value) -> Any

	public var isDeinitialized: Bool {
		return object == nil
	}

	/// The current value in the key path of the underlying object, or `nil` if
	/// the value is null or the object has deinitialized.
	public var value: Value? {
		get {
			return object?.value(forKeyPath: keyPath).map(extractValue)
		}

		set(newValue) {
			object?.setValue(newValue.map(represent), forKeyPath: keyPath)
		}
	}

	/// The lifetime of the underlying object.
	public var lifetime: Lifetime {
		return object?.rac_lifetime ?? .empty
	}

	/// A producer that send the initial value then all changes over time of the
	/// property, and then complete when the underlying object deinitializes.
	///
	/// If the object has deinitialized, a completed producer would be returned.
	public var producer: SignalProducer<Value?, NoError> {
		let source = object?.values(forKeyPath: keyPath) ?? .empty
		return source.map { [transform = extractValue] in $0.map(transform) }
	}

	public lazy var signal: Signal<Value?, NoError> = { [unowned self] in
		var signal: Signal<DynamicProperty.Value, NoError>!
		self.producer.startWithSignal { innerSignal, _ in signal = innerSignal }
		return signal
	}()

	/// Initializes a property that acts as a weak lens to the given key path of
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
		return target.object.flatMap { object in
			return signal
				.take(during: object.rac_lifetime)
				.observeNext { [weak object = target.object, represent = target.represent, keyPath = target.keyPath] value in
					object?.setValue(represent(value), forKeyPath: keyPath)
				}
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
