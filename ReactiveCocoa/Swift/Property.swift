import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
public protocol PropertyType {
	associatedtype Value

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	var producer: SignalProducer<Value, NoError> { get }

	/// A signal that will send the property's changes over time.
	var signal: Signal<Value, NoError> { get }

	/// Performs an arbitrary action using the current value of the
	/// variable. Conforming types may optionally guarantee atomicity.
	///
	/// Returns the result of the action.
	func withValue<Result>(@noescape action: Value throws -> Result) rethrows -> Result
}

/// Represents an observable property that can be mutated directly.
///
/// Only classes can conform to this protocol, because instances must support
/// weak references (and value types currently do not).
public protocol MutablePropertyType: class, PropertyType {
	func modify(@noescape action: Value throws -> Value) rethrows -> Value
}

extension PropertyType {
	public var value: Value {
		return withValue { $0 }
	}

	/// Maps the current value and all subsequent values to a new value.
	///
	/// A mapped property would retain its source property.
	public func map<U>(transform: Value -> U) -> AnyProperty<U> {
		return withValue { currentValue in
			let producer = SignalProducer(signal: signal)
				.map(transform)
				.on(completed: { self })

			return AnyProperty(initialValue: transform(currentValue), producer: producer)
		}
	}

	/// Combine the current value and all subsequent values from two `Property`s
	/// to obtain a new value by applying the supplied transform.
	///
	/// A combined property would retain its source properties.
	public func combineLatest<P: PropertyType, U>(with other: P, combining transform: (Value, P.Value) -> U) -> AnyProperty<U> {
		return withValue { currentValue in
			return other.withValue { currentOtherValue in
				let combinedProducer = SignalProducer(value: currentValue).takeUntilReplacement(signal)
					.combineLatestWith(SignalProducer(value: currentOtherValue).takeUntilReplacement(other.signal))
					.map(transform)
					.on(completed: { self; other })

				return AnyProperty(initialValue: transform((currentValue, currentOtherValue)), producer: combinedProducer)
			}
		}
	}

	/// Combine the current value and all subsequent values from two `Property`s
	/// to a tuple.
	///
	/// A zipped property would retain its source properties.
	public func combineLatest<P: PropertyType>(with other: P) -> AnyProperty<(Value, P.Value)> {
		return combineLatest(with: other, combining: { $0 })
	}

	/// Zip the current value and all subsequent values from two `Property`s
	/// to obtain a new value by applying the supplied transform.
	///
	/// A zipped property would retain its source properties.
	public func zip<P: PropertyType, U>(with other: P, combining transform: (Value, P.Value) -> U) -> AnyProperty<U> {
		return withValue { currentValue in
			return other.withValue { currentOtherValue in
				let zippedProducer = SignalProducer(signal: signal)
					.zipWith(SignalProducer(signal: other.signal))
					.map(transform)
					.on(completed: { self; other })

				return AnyProperty(initialValue: transform((currentValue, currentOtherValue)), producer: zippedProducer)
			}
		}
	}

	/// Zip the current value and all subsequent values from two `Property`s
	/// to a tuple.
	///
	/// A zipped property would retain its source properties.
	public func zip<P: PropertyType>(with other: P) -> AnyProperty<(Value, P.Value)> {
		return zip(with: other, combining: { $0 })
	}
}

extension MutablePropertyType {
	public var value: Value {
		get { return withValue { $0 } }
		set { swap(newValue) }
	}

	/// Atomically modifies the variable. Conforming types may optionally
	/// guarantee atomicity.
	///
	/// Returns the old value.
	public func swap(newValue: Value) -> Value {
		return modify { _ in newValue }
	}
}

/// A read-only property that allows observation of its changes.
public struct AnyProperty<Value>: PropertyType {
	private let box: AnyPropertyBoxBase<Value>

	public var signal: Signal<Value, NoError> {
		return box.signal
	}

	public var producer: SignalProducer<Value, NoError> {
		return box.producer
	}

	/// Initializes a property as a read-only view of the given property.
	public init<P: PropertyType where P.Value == Value>(_ property: P) {
		box = AnyPropertyBox(property)
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

	public func withValue<Result>(@noescape action: Value throws -> Result) rethrows -> Result {
		return try box.withValue(action)
	}
}

/// A type-erased view to the underlying property which allows mutation of the
/// value.
public class AnyMutableProperty<Value>: MutablePropertyType {
	private let box: AnyPropertyBoxBase<Value>

	public var signal: Signal<Value, NoError> {
		return box.signal
	}

	public var producer: SignalProducer<Value, NoError> {
		return box.producer
	}

	/// Initializes a property as a read-only view of the given property.
	public init<P: MutablePropertyType where P.Value == Value>(_ property: P) {
		box = AnyMutablePropertyBox(property)
	}

	public func withValue<Result>(@noescape action: Value throws -> Result) rethrows -> Result {
		return try box.withValue(action)
	}

	public func modify(@noescape action: Value throws -> Value) rethrows -> Value {
		return try box.modify(action)
	}
}

/// A property that never changes.
public struct ConstantProperty<Value>: PropertyType {

	public let value: Value
	public let producer: SignalProducer<Value, NoError>
	public let signal: Signal<Value, NoError>

	/// Initializes the property to have the given value.
	public init(_ value: Value) {
		self.value = value
		self.producer = SignalProducer(value: value)
		self.signal = .empty
	}

	public func withValue<Result>(@noescape action: Value throws -> Result) rethrows -> Result {
		return try action(value)
	}
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

	/// Initializes the property with the given value to start.
	public init(_ initialValue: Value) {
		var value = initialValue

		lock = NSRecursiveLock()
		lock.name = "org.reactivecocoa.ReactiveCocoa.MutableProperty"

		getter = { value }
		setter = { newValue in value = newValue }

		(signal, observer) = Signal.pipe()
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
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
	/// Returns the result of the action.
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
	var disposable: Disposable!

	producer.startWithSignal { signal, signalDisposable in
		property <~ signal
		disposable = signalDisposable

		property.producer.startWithCompleted {
			signalDisposable.dispose()
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

/// The type-erasing box for `AnyMutableProperty`.
private class AnyMutablePropertyBox<P: MutablePropertyType>: AnyPropertyBox<P> {
	override init(_ property: P) {
		super.init(property)
	}

	override func modify(@noescape action: P.Value throws -> P.Value) rethrows -> P.Value {
		return try wrappingProperty.modify(action)
	}
}

/// The type-erasing box for `AnyProperty`.
private class AnyPropertyBox<P: PropertyType>: AnyPropertyBoxBase<P.Value> {
	let wrappingProperty: P

	init(_ property: P) {
		wrappingProperty = property
	}

	override var signal: Signal<P.Value, NoError> {
		return wrappingProperty.signal
	}

	override var producer: SignalProducer<P.Value, NoError> {
		return wrappingProperty.producer
	}

	override func withValue<Result>(@noescape action: P.Value throws -> Result) rethrows -> Result {
		return try wrappingProperty.withValue(action)
	}
}

/// The base class of the type-erasing boxes.
private class AnyPropertyBoxBase<Value>: PropertyType {
	var signal: Signal<Value, NoError> {
		fatalError("This method should have been overriden by a subclass.")
	}

	var producer: SignalProducer<Value, NoError> {
		fatalError("This method should have been overriden by a subclass.")
	}

	func withValue<Result>(@noescape action: Value throws -> Result) rethrows -> Result {
		fatalError("This method should have been overriden by a subclass.")
	}

	func modify(@noescape action: Value throws -> Value) rethrows -> Value {
		fatalError("This method should have been overriden by a subclass.")
	}
}
