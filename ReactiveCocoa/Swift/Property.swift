import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
public protocol PropertyType {
	associatedtype Value

	/// The current value of the property.
	var value: Value { get }

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time.
	var producer: SignalProducer<Value, NoError> { get }

	/// A signal that will send the property's changes over time.
	var signal: Signal<Value, NoError> { get }
}

/// A read-only property that allows observation of its changes.
public struct AnyProperty<Value>: PropertyType {

	private let _value: () -> Value
	private let _producer: () -> SignalProducer<Value, NoError>
	private let _signal: () -> Signal<Value, NoError>


	public var value: Value {
		return _value()
	}

	public var producer: SignalProducer<Value, NoError> {
		return _producer()
	}

	public var signal: Signal<Value, NoError> {
		return _signal()
	}
	
	/// Initializes a property as a read-only view of the given property.
	///
	/// - parameters:
	///   - property: A property to read as this property's own value.
	public init<P: PropertyType where P.Value == Value>(_ property: P) {
		_value = { property.value }
		_producer = { property.producer }
		_signal = { property.signal }
	}
	
	/// Initializes a property that first takes on `initialValue`, then each
	/// value sent on a signal created by `producer`.
	///
	/// - parameters:
	///   - initialValue: Starting value for the property.
	///   - producer: A producer that will start immediately and send values to
	///               the property.
	public init(initialValue: Value, producer: SignalProducer<Value, NoError>) {
		let mutableProperty = MutableProperty(initialValue)
		mutableProperty <~ producer
		self.init(mutableProperty)
	}
	
	/// Initializes a property that first takes on `initialValue`, then each
	/// value sent on `signal`.
	///
	/// - parameters:
	///   - initialValue: Starting value for the property.
	///   - signal: A signal that will send values to the property.
	public init(initialValue: Value, signal: Signal<Value, NoError>) {
		let mutableProperty = MutableProperty(initialValue)
		mutableProperty <~ signal
		self.init(mutableProperty)
	}
}

extension PropertyType {
	/// Maps the current value and all subsequent values to a new value.
	///
	/// - parameters:
	///   - transform: A closure that will map the current `value` of this
	///                `Property` to a new value.
	///
	/// - returns: A new instance of `AnyProperty` who's holds a mapped value
	///            from `self`.
	public func map<U>(transform: Value -> U) -> AnyProperty<U> {
		let mappedProducer = SignalProducer<U, NoError> { observer, disposable in
			disposable += ActionDisposable { self }
			disposable += self.producer.map(transform).start(observer)
		}
		return AnyProperty(initialValue: transform(value), producer: mappedProducer)
	}
}

/// A property that never changes.
public struct ConstantProperty<Value>: PropertyType {

	public let value: Value
	public let producer: SignalProducer<Value, NoError>
	public let signal: Signal<Value, NoError>

	/// Initializes the property to have the given value.
	///
	/// - parameters:
	///   - value: Property's value.
	public init(_ value: Value) {
		self.value = value
		self.producer = SignalProducer(value: value)
		self.signal = .empty
	}
}

/// Represents an observable property that can be mutated directly.
///
/// Only classes can conform to this protocol, because instances must support
/// weak references (and value types currently do not).
public protocol MutablePropertyType: class, PropertyType {
	var value: Value { get set }
}

/// A mutable property of type `Value` that allows observation of its changes.
///
/// Instances of this class are thread-safe.
public final class MutableProperty<Value>: MutablePropertyType {

	private let observer: Signal<Value, NoError>.Observer

	/// Need a recursive lock around `value` to allow recursive access to
	/// `value`. Note that recursive sets will still deadlock because the
	/// underlying producer prevents sending recursive events.
	private let lock: NSRecursiveLock

	/// The getter of the underlying storage, which may outlive the property
	/// if a returned producer is being retained.
	private let getter: () -> Value

	/// The setter of the underlying storage.
	private let setter: Value -> Void

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all observers of any Signals
	/// created from the `values` producer.
	public var value: Value {
		get {
			return withValue { $0 }
		}

		set {
			swap(newValue)
		}
	}

	/// A signal that will send the property's changes over time,
	/// then complete when the property has deinitialized.
	public let signal: Signal<Value, NoError>

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	public var producer: SignalProducer<Value, NoError> {
		return SignalProducer { [getter, weak self] producerObserver, producerDisposable in
			if let strongSelf = self {
				strongSelf.withValue { value in
					producerObserver.sendNext(value)
					producerDisposable += strongSelf.signal.observe(producerObserver)
				}
			} else {
				/// As the setter would have been deinitialized with the property,
				/// the underlying storage would be immutable, and locking is no longer necessary.
				producerObserver.sendNext(getter())
				producerObserver.sendCompleted()
			}
		}
	}

	/// Initializes a mutable property that first takes on `initialValue`
	///
	/// - parameters:
	///   - initialValue: Starting value for the mutable property.
	public init(_ initialValue: Value) {
		var value = initialValue

		lock = NSRecursiveLock()
		lock.name = "org.reactivecocoa.ReactiveCocoa.MutableProperty"

		getter = { value }
		setter = { newValue in value = newValue }

		(signal, observer) = Signal.pipe()
	}

	/// Atomically replaces the contents of the variable.
	///
	/// - parameters:
	///   - newValue: New property value.
	///
	/// - returns: The previous property value.
	public func swap(newValue: Value) -> Value {
		return modify { _ in newValue }
	}

	/// Atomically modifies the variable.
	///
	/// - parameters:
	///   - action: A closure that accepts old property value and returns a new
	///             property value.
	/// - returns: The previous property value.
	public func modify(@noescape action: (Value) throws -> Value) rethrows -> Value {
		return try withValue { value in
			let newValue = try action(value)
			setter(newValue)
			observer.sendNext(newValue)
			return value
		}
	}

	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// - parameters:
	///   - action: A closure that accepts current property value.
	///
	/// - returns: the result of the action.
	public func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
		lock.lock()
		defer { lock.unlock() }

		return try action(getter())
	}

	deinit {
		observer.sendCompleted()
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
/// - note: The binding will automatically terminate when the property is 
///         deinitialized, or when the signal sends a `Completed` event.
///
/// ````
/// let property = MutableProperty(0)
/// let signal = Signal({ /* do some work after some time */ })
/// property <~ signal
/// ````
///
/// ````
/// let property = MutableProperty(0)
/// let signal = Signal({ /* do some work after some time */ })
/// let disposable = property <~ signal
/// ...
/// // Terminates binding before property dealloc or signal's 
/// // `Completed` event.
/// disposable.dispose()
/// ````
///
/// - parameters:
///   - property: A property to bind to.
///   - signal: A signal to bind.
///
/// - returns: A disposable that can be used to terminate binding before the
///            deinitialization of property or signal's `Completed` event.
public func <~ <P: MutablePropertyType>(property: P, signal: Signal<P.Value, NoError>) -> Disposable {
	let disposable = CompositeDisposable()
	disposable += property.producer.startWithCompleted {
		disposable.dispose()
	}

	disposable += signal.observe { [weak property] event in
		switch event {
		case let .Next(value):
			property?.value = value
		case .Completed:
			disposable.dispose()
		case .Failed, .Interrupted:
			break
		}
	}

	return disposable
}


/// Creates a signal from the given producer, which will be immediately bound to
/// the given property, updating the property's value to the latest value sent
/// by the signal.
///
/// ````
/// let property = MutableProperty(0)
/// let producer = SignalProducer<Int, NoError>(value: 1)
/// property <~ producer
/// print(property.value) // prints `1`
/// ````
///
/// ````
/// let property = MutableProperty(0)
/// let producer = SignalProducer({ /* do some work after some time */ })
/// let disposable = (property <~ producer)
/// ...
/// // Terminates binding before property dealloc or
/// // signal's `Completed` event.
/// disposable.dispose()
/// ````
///
/// - note: The binding will automatically terminate when the property is 
///         deinitialized, or when the created producer sends a `Completed` 
///         event.
///
/// - parameters:
///   - property: A property to bind to.
///   - producer: A producer to bind.
///
/// - returns: A disposable that can be used to terminate binding before the
///            deinitialization of property or producer's `Completed` event.
public func <~ <P: MutablePropertyType>(property: P, producer: SignalProducer<P.Value, NoError>) -> Disposable {
	let disposable = CompositeDisposable()

	producer
		.on(completed: { disposable.dispose() })
		.startWithSignal { signal, signalDisposable in
			disposable += property <~ signal
			disposable += signalDisposable

			disposable += property.producer.startWithCompleted {
				disposable.dispose()
			}
		}

	return disposable
}


/// Binds `destinationProperty` to the latest values of `sourceProperty`.
///
/// ````
/// let dstProperty = MutableProperty(0)
/// let srcProperty = ConstantProperty(10)
/// dstProperty <~ srcProperty
/// print(dstProperty.value) // prints 10
/// ````
///
/// ````
/// let dstProperty = MutableProperty(0)
/// let srcProperty = ConstantProperty(10)
/// let disposable = (dstProperty <~ srcProperty)
/// ...
/// disposable.dispose() // terminate the binding earlier if
///                      // needed
/// ````
///
/// - note: The binding will automatically terminate when either property is
///         deinitialized.
///
/// - parameters:
///   - destinationProperty: A property to bind to.
///   - sourceProperty: A property to bind.
///
/// - returns: A disposable that can be used to terminate binding before the
///            deinitialization of destination property or source property
///            producer's `Completed` event.
public func <~ <Destination: MutablePropertyType, Source: PropertyType where Source.Value == Destination.Value>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
}
