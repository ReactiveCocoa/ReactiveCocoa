import Foundation
import enum Result.NoError

/// Wraps a `dynamic` property, or one defined in Objective-C, using Key-Value
/// Coding and Key-Value Observing.
///
/// Use this class only as a last resort! `MutableProperty` is generally better
/// unless KVC/KVO is required by the API you're using (for example,
/// `NSOperation`).
@objc public final class DynamicProperty: RACDynamicPropertySuperclass, MutablePropertyType {
	public typealias Value = AnyObject?
	public typealias Input = Value

	private weak var object: NSObject?
	private let keyPath: String

	private var property: MutableProperty<AnyObject?>?

	/// The current value of the property, as read and written using Key-Value
	/// Coding.
	public var value: AnyObject? {
		@objc(rac_value) get {
			return object?.valueForKeyPath(keyPath)
		}

		@objc(setRac_value:) set(newValue) {
			object?.setValue(newValue, forKeyPath: keyPath)
		}
	}

	/// A producer that will create a Key-Value Observer for the given object,
	/// send its initial value then all changes over time, and then complete
	/// when the observed object has deallocated.
	///
	/// By definition, this only works if the object given to init() is
	/// KVO-compliant. Most UI controls are not!
	public var producer: SignalProducer<AnyObject?, NoError> {
		return property?.producer ?? .empty
	}

	public var signal: Signal<AnyObject?, NoError> {
		return property?.signal ?? .empty
	}

	public let complete: Signal<(), NoError>?

	/// Initializes a property that will observe and set the given key path of
	/// the given object. `object` must support weak references!
	public init(object: NSObject?, keyPath: String) {
		self.object = object
		self.keyPath = keyPath
		self.property = MutableProperty(nil)
		self.complete = object?.rac_willDealloc ?? .empty

		/// DynamicProperty stay alive as long as object is alive.
		/// This is made possible by strong reference cycles.
		super.init()

		object?.rac_valuesForKeyPath(keyPath, observer: nil)?
			.toSignalProducer()
			.start { event in
				switch event {
				case let .Next(newValue):
					self.property?.value = newValue
				case let .Failed(error):
					fatalError("Received unexpected error from KVO signal: \(error)")
				case .Interrupted, .Completed:
					self.property = nil
				}
			}
	}
}

// MARK: Operators

/// Binds a signal to a `DynamicProperty`, automatically bridging values to Objective-C.
public func <~ <Value: _ObjectiveCBridgeable>(property: DynamicProperty, signal: Signal<Value, NoError>) -> Disposable {
	return property <~ signal.map { $0._bridgeToObjectiveC() }
}

/// Binds a signal producer to a `DynamicProperty`, automatically bridging values to Objective-C.
public func <~ <Value: _ObjectiveCBridgeable>(property: DynamicProperty, producer: SignalProducer<Value, NoError>) -> Disposable {
	return property <~ producer.map { $0._bridgeToObjectiveC() }
}

/// Binds `destinationProperty` to the latest values of `sourceProperty`, automatically bridging values to Objective-C.
public func <~ <Source: PropertyType where Source.Value: _ObjectiveCBridgeable>(destinationProperty: DynamicProperty, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
}
