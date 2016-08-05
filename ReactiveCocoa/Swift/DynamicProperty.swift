import Foundation
import enum Result.NoError

/// Models types that can be represented in Objective-C (i.e., reference
/// types, including generic types when boxed via `AnyObject`).
private protocol ObjectiveCRepresentable {
	associatedtype Value
	static func extract(from representation: AnyObject) -> Value
	static func represent(_ value: Value) -> AnyObject
}

/// Wraps a `dynamic` property, or one defined in Objective-C, using Key-Value
/// Coding and Key-Value Observing.
///
/// Use this class only as a last resort! `MutableProperty` is generally better
/// unless KVC/KVO is required by the API you're using (for example,
/// `NSOperation`).
public final class DynamicProperty<Value>: MutablePropertyProtocol {
	private let object: NSObject
	private let keyPath: String

	private let represent: (Value) -> AnyObject

	private var disposable: Disposable!
	private var _value: Value?

	/// The current value of the property.
	public var value: Value? {
		get {
			return _value
		}

		set(newValue) {
			object.setValue(newValue.map(represent), forKeyPath: keyPath)
		}
	}

	/// A producer that will create a Key-Value Observer for the given object,
	/// send its initial value then all changes over time, and then complete
	/// when the observed object has deallocated.
	///
	/// - important: This only works if the object given to init() is KVO-compliant.
	///              Most UI controls are not!
	public let producer: SignalProducer<Value?, NoError>

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
	private init<Representatable: ObjectiveCRepresentable where Representatable.Value == Value>(object: NSObject, keyPath: String, representable: Representatable.Type) {
		self.object = object
		self.keyPath = keyPath

		self.represent = Representatable.represent

		self.producer = object.values(forKeyPath: keyPath)
			.map { $0.map(Representatable.extract(from:)) }
			.replayLazily(upTo: 1)

		self.disposable = producer.startWithNext { [weak self] value in
			self?._value = value
		}
	}

	deinit {
		disposable.dispose()
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
	public convenience init(object: NSObject, keyPath: String) {
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
	public convenience init(object: NSObject, keyPath: String) {
		self.init(object: object, keyPath: keyPath, representable: DirectRepresentation.self)
	}
}

/// Represents values in Objective-C directly, via `AnyObject`.
private struct DirectRepresentation<Value: AnyObject>: ObjectiveCRepresentable {
	static func extract(from representation: AnyObject) -> Value {
		return representation as! Value
	}

	static func represent(_ value: Value) -> AnyObject {
		return value
	}
}

/// Represents values in Objective-C indirectly, via bridging.
private struct BridgeableRepresentation<Value: _ObjectiveCBridgeable>: ObjectiveCRepresentable {
	static func extract(from representation: AnyObject) -> Value {
		let object = representation as! Value._ObjectiveCType
		var result: Value?
		Value._forceBridgeFromObjectiveC(object, result: &result)
		return result!
	}

	static func represent(_ value: Value) -> AnyObject {
		return value._bridgeToObjectiveC()
	}
}
