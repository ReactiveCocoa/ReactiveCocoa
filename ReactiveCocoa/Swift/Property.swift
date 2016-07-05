import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
public protocol PropertyType {
	associatedtype Value

	/// The atomic value of the property.
	var atomic: AnyAtomic<Value> { get }

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time.
	var producer: SignalProducer<Value, NoError> { get }

	/// A signal that will send the property's changes over time.
	var signal: Signal<Value, NoError> { get }
}

public extension PropertyType {
	/// Atomically performs an arbitrary action using the current value of the
	/// property.
	///
	/// Returns the result of the action.
	public func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
		return try self.atomic.withValue(action)
	}
}

public extension PropertyType {
	/// The current value of the property.
	var value: Value {
		return self.withValue { $0 }
	}
}

/// A read-only property that allows observation of its changes.
public struct AnyProperty<Value>: PropertyType {

	private let _atomic: () -> AnyAtomic<Value>
	private let _producer: () -> SignalProducer<Value, NoError>
	private let _signal: () -> Signal<Value, NoError>

	public var atomic: AnyAtomic<Value> {
		return _atomic()
	}

	public var producer: SignalProducer<Value, NoError> {
		return _producer()
	}

	public var signal: Signal<Value, NoError> {
		return _signal()
	}

	/// Initializes a property as a read-only view of the given property.
	public init<P: PropertyType where P.Value == Value>(_ property: P) {
		_atomic = { property.atomic }
		_producer = { property.producer }
		_signal = { property.signal }
	}
	
	/// Initializes a property that first takes on `initialValue`, then each value
	/// sent on a signal created by `producer`.
	public init(initialValue: Value, producer: SignalProducer<Value, NoError>) {
		let mutableProperty = MutableProperty(initialValue)
		mutableProperty <~ producer
		self.init(mutableProperty)
	}
	
	/// Initializes a property that first takes on `initialValue`, then each value
	/// sent on `signal`.
	public init(initialValue: Value, signal: Signal<Value, NoError>) {
		let mutableProperty = MutableProperty(initialValue)
		mutableProperty <~ signal
		self.init(mutableProperty)
	}
}

extension PropertyType {
	/// Maps the current value and all subsequent values to a new value.
	public func map<U>(transform: Value -> U) -> AnyProperty<U> {
		return self.withValue { value in
			let mappedProducer = SignalProducer<U, NoError> { observer, disposable in
				disposable += ActionDisposable { self }
				disposable += self.producer.map(transform).start(observer)
				return AnyProperty(initialValue: transform(value), producer: mappedProducer)
			}
		}
}

/// A property that never changes.
public struct ConstantProperty<Value>: PropertyType {

	public let atomic: AnyAtomic<Value>
	public let producer: SignalProducer<Value, NoError>
	public let signal: Signal<Value, NoError>

	/// Initializes the property to have the given value.
	public init(_ value: Value) {
		self.atomic = AnyAtomic(value: value)
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
	private var _value: Atomic<Value>

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

	public var atomic: AnyAtomic<Value> {
		return AnyAtomic(atomic: _value)
	}

	/// A signal that will send the property's changes over time,
	/// then complete when the property has deinitialized.
	public let signal: Signal<Value, NoError>

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	public var producer: SignalProducer<Value, NoError> {
		return SignalProducer { [_value, weak self] producerObserver, producerDisposable in
			if let strongSelf = self {
				strongSelf.withValue { value in
					producerObserver.sendNext(value)
					producerDisposable += strongSelf.signal.observe(producerObserver)
				}
			} else {
				/// As the setter would have been deinitialized with the property,
				/// the underlying storage would be immutable, and locking is no longer necessary.
				producerObserver.sendNext(_value.value)
				producerObserver.sendCompleted()
			}
		}
	}

	/// Initializes the property with the given value to start.
	public init(_ initialValue: Value) {
		_value = Atomic(initialValue, mutex: RecursiveLock("org.reactivecocoa.ReactiveCocoa.MutableProperty"))
		(signal, observer) = Signal.pipe()
	}

	/// Atomically replaces the contents of the variable.
	///
	/// Returns the old value.
	public func swap(newValue: Value) -> Value {
		return modify { _ in newValue }
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	public func modify(@noescape action: (Value) throws -> Value) rethrows -> Value {
		return try _value.modify(action, completion: observer.sendNext)
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
/// The binding will automatically terminate when the property is deinitialized,
/// or when the signal sends a `Completed` event.
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
/// The binding will automatically terminate when the property is deinitialized,
/// or when the created signal sends a `Completed` event.
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
/// The binding will automatically terminate when either property is
/// deinitialized.
public func <~ <Destination: MutablePropertyType, Source: PropertyType where Source.Value == Destination.Value>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
}
