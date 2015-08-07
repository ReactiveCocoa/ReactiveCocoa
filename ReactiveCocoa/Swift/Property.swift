/// Represents a property that allows observation of its changes.
public protocol PropertyType {
	typealias Value

	/// The current value of the property.
	var value: Value { get }

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time.
	var producer: SignalProducer<Value, NoError> { get }
}

/// A read-only property that allows observation of its changes.
public struct PropertyOf<T>: PropertyType {
	public typealias Value = T

	private let _value: () -> T
	private let _producer: () -> SignalProducer<T, NoError>

	public var value: T {
		return _value()
	}

	public var producer: SignalProducer<T, NoError> {
		return _producer()
	}
	
	/// Initializes a property as a read-only view of the given property.
	public init<P: PropertyType where P.Value == T>(_ property: P) {
		_value = { property.value }
		_producer = { property.producer }
	}
	
	/// Initializes a property that first takes on `initialValue`, then each value 
	/// sent on a signal created by `producer`.
	public init(initialValue: T, producer: SignalProducer<T, NoError>) {
		let mutableProperty = MutableProperty(initialValue)
		mutableProperty <~ producer
		self.init(mutableProperty)
	}
	
	/// Initializes a property that first takes on `initialValue`, then each value
	/// sent on `signal`.
	public init(initialValue: T, signal: Signal<T, NoError>) {
		let mutableProperty = MutableProperty(initialValue)
		mutableProperty <~ signal
		self.init(mutableProperty)
	}
}

/// A property that never changes.
public struct ConstantProperty<T>: PropertyType {
	public typealias Value = T

	public let value: T
	public let producer: SignalProducer<T, NoError>

	/// Initializes the property to have the given value.
	public init(_ value: T) {
		self.value = value
		self.producer = SignalProducer(value: value)
	}
}

/// Represents an observable property that can be mutated directly.
///
/// Only classes can conform to this protocol, because instances must support
/// weak references (and value types currently do not).
public protocol MutablePropertyType: class, PropertyType {
	var value: Value { get set }
}

/// A mutable property of type T that allows observation of its changes.
///
/// Instances of this class are thread-safe.
public final class MutableProperty<T>: MutablePropertyType {
	public typealias Value = T

	private let observer: Signal<T, NoError>.Observer

	/// Need a recursive lock around `value` to allow recursive access to
	/// `value`. Note that recursive sets will still deadlock because the
	/// underlying producer prevents sending recursive events.
	private let lock = NSRecursiveLock()
	private var _value: T

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all observers of any Signals
	/// created from the `values` producer.
	public var value: T {
		get {
			lock.lock()
			let value = _value
			lock.unlock()
			return value
		}

		set {
			lock.lock()
			_value = newValue
			sendNext(observer, newValue)
			lock.unlock()
		}
	}

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	public let producer: SignalProducer<T, NoError>

	/// Initializes the property with the given value to start.
	public init(_ initialValue: T) {
		lock.name = "org.reactivecocoa.ReactiveCocoa.MutableProperty"

		(producer, observer) = SignalProducer<T, NoError>.buffer(1)

		_value = initialValue
		sendNext(observer, initialValue)
	}

	deinit {
		sendCompleted(observer)
	}
}

/// Wraps a `dynamic` property, or one defined in Objective-C, using Key-Value
/// Coding and Key-Value Observing.
///
/// Use this class only as a last resort! `MutableProperty` is generally better
/// unless KVC/KVO is required by the API you're using (for example,
/// `NSOperation`).
@objc public final class DynamicProperty: RACDynamicPropertySuperclass, MutablePropertyType {
	public typealias Value = AnyObject?

	private weak var object: NSObject?
	private let keyPath: String

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
		if let object = object {
			return object.rac_valuesForKeyPath(keyPath, observer: nil).toSignalProducer()
				// Errors aren't possible, but the compiler doesn't know that.
				.flatMapError { error in
					assert(false, "Received unexpected error from KVO signal: \(error)")
					return .empty
				}
		} else {
			return .empty
		}
	}

	/// Initializes a property that will observe and set the given key path of
	/// the given object. `object` must support weak references!
	public init(object: NSObject?, keyPath: String) {
		self.object = object
		self.keyPath = keyPath
		
		/// DynamicProperty stay alive as long as object is alive.
		/// This is made possible by strong reference cycles.
		super.init()
		object?.rac_willDeallocSignal()?.toSignalProducer().start(completed: { self })
	}
}

infix operator <~ {
	associativity right

	// Binds tighter than assignment but looser than everything else
	precedence 93
}

/// Binds a signal to a property, updating the property's value to the latest
/// value sent by the signal.
///
/// The binding will automatically terminate when the property is deinitialized,
/// or when the signal sends a `Completed` event.
public func <~ <P: MutablePropertyType>(property: P, signal: Signal<P.Value, NoError>) -> Disposable {
	let disposable = CompositeDisposable()
	disposable += property.producer.start(completed: {
		disposable.dispose()
	})

	disposable += signal.observe(next: { [weak property] value in
		property?.value = value
	}, completed: {
		disposable.dispose()
	})

	return disposable
}


/// Creates a signal from the given producer, which will be immediately bound to
/// the given property, updating the property's value to the latest value sent
/// by the signal.
///
/// The binding will automatically terminate when the property is deinitialized,
/// or when the created signal sends a `Completed` event.
public func <~ <P: MutablePropertyType>(property: P, producer: SignalProducer<P.Value, NoError>) -> Disposable {
	var disposable: Disposable!

	producer.startWithSignal { signal, signalDisposable in
		property <~ signal
		disposable = signalDisposable

		property.producer.start(completed: {
			signalDisposable.dispose()
		})
	}

	return disposable
}


/// Binds `destinationProperty` to the latest values of `sourceProperty`.
///
/// The binding will automatically terminate when either property is
/// deinitialized.
public func <~ <Destination: MutablePropertyType, Source: PropertyType where Source.Value == Destination.Value>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
}
