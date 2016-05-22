import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
public protocol PropertyType {
	associatedtype Value

	/// The current value of the property.
	var value: Value { get }

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	var producer: SignalProducer<Value, NoError> { get }

	/// A signal that will send the property's changes over time, then complete
	/// when the property has deinitialized.
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
	/// The current value of the property.
	var value: Value { get set }

	/// Modifies the variable. Conforming types may optionally
	/// guarantee atomicity.
	///
	/// Returns the old value.
	func modify(@noescape action: Value throws -> Value) rethrows -> Value
}

extension PropertyType {
	/// The current value of the property.
	public var value: Value {
		return withValue { $0 }
	}
}

/// Workaround of the nil coalescing operator, as it does not work as
/// intended with function types.
///
/// https://bugs.swift.org/browse/SR-832
private func coalescing<T>(optional: T?, default value: T) -> T {
	return optional ?? value
}

/// Protocol composition operators
///
/// The producer and the signal of transformed properties would complete
/// only when its source properties have deinitialized.
///
/// A transformed property would retain its ultimate source, but not
/// any intermediate property during the composition.
extension PropertyType {
	/// Lifts an unary SignalProducer operator to operate upon PropertyType instead.
	@warn_unused_result(message="Did you forget to use the composed property?")
	private func lift<U>(@noescape transform: SignalProducer<Value, NoError> -> SignalProducer<U, NoError>) -> AnyProperty<U> {
		let capturingClosure = coalescing((self as? AnyProperty<Value>)?.box.capturingClosure, default: { self })

		return AnyProperty(propertyProducer: transform(producer),
		                   capturing: capturingClosure)
	}

	/// Lifts a binary SignalProducer operator to operate upon PropertyType instead.
	@warn_unused_result(message="Did you forget to use the composed property?")
	private func lift<P: PropertyType, U>(transform: SignalProducer<Value, NoError> -> SignalProducer<P.Value, NoError> -> SignalProducer<U, NoError>) -> P -> AnyProperty<U> {
		return { otherProperty in
			let capturingClosure = coalescing((self as? AnyProperty<Value>)?.box.capturingClosure, default: { self })
			let otherCapturingClosure = coalescing((otherProperty as? AnyProperty<P.Value>)?.box.capturingClosure, default: { otherProperty })

			return AnyProperty(propertyProducer: transform(self.producer)(otherProperty.producer),
			                   capturing: { _ = capturingClosure; _ = otherCapturingClosure })
		}
	}

	/// Maps the current value and all subsequent values to a new property.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func map<U>(transform: Value -> U) -> AnyProperty<U> {
		return lift { $0.map(transform) }
	}

	/// Combines the current value and the subsequent values of two `Property`s in
	/// the manner described by `Signal.combineLatestWith:`.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func combineLatest<P: PropertyType>(with other: P) -> AnyProperty<(Value, P.Value)> {
		return lift(SignalProducer.combineLatestWith)(other)
	}

	/// Zips the current value and the subsequent values of two `Property`s in
	/// the manner described by `Signal.zipWith`.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func zip<P: PropertyType>(with other: P) -> AnyProperty<(Value, P.Value)> {
		return lift(SignalProducer.zipWith)(other)
	}

	/// Forwards events from `self` with history: values of the returned property
	/// are a tuple whose first member is the previous value and whose second member
	/// is the current value. `initial` is supplied as the first member of the first
	/// tuple.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func combinePrevious(initial: Value) -> AnyProperty<(Value, Value)> {
		return lift { $0.combinePrevious(initial) }
	}

	/// Forwards only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value. The first value is always forwarded.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func skipRepeats(isRepeat: (Value, Value) -> Bool) -> AnyProperty<Value> {
		return lift { $0.skipRepeats(isRepeat) }
	}
}

extension PropertyType where Value: Equatable {
	/// Forwards only those values from `self` which is not equal to the previous
	/// value. The first value is always forwarded.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func skipRepeats() -> AnyProperty<Value> {
		return lift { $0.skipRepeats() }
	}
}

public enum PropertyFlattenStrategy {
	case Latest
}

extension PropertyType where Value: PropertyType {
	/// Returns a property that forwards values from the latest property hold by
	/// `self`, ignoring values sent on previous inner properties.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func flatten(strategy: PropertyFlattenStrategy) -> AnyProperty<Value.Value> {
		switch strategy {
		case .Latest:
			return lift { $0.flatMap(.Latest) { $0.producer } }
		}
	}
}

extension PropertyType {
	/// Maps a property to a new property, and then flattens it in the manner
	/// described by `flattenLatest`.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func flatMap<P: PropertyType>(strategy: PropertyFlattenStrategy, transform: Value -> P) -> AnyProperty<P.Value> {
		switch strategy {
		case .Latest:
			return lift { $0.flatMap(.Latest) { transform($0).producer } }
		}
	}

	/// Forwards only those values from `self` that have unique identities across the set of
	/// all values that have been seen.
	///
	/// Note: This causes the identities to be retained to check for uniqueness.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func uniqueValues<Identity: Hashable>(transform: Value -> Identity) -> AnyProperty<Value> {
		return lift { $0.uniqueValues(transform) }
	}
}

extension PropertyType where Value: Hashable {
	/// Forwards only those values from `self` that are unique across the set of
	/// all values that have been seen.
	///
	/// Note: This causes the values to be retained to check for uniqueness. Providing
	/// a function that returns a unique value for each sent value can help you reduce
	/// the memory footprint.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func uniqueValues() -> AnyProperty<Value> {
		return lift { $0.uniqueValues() }
	}
}

extension MutablePropertyType {
	public var value: Value {
		get { return withValue { $0 } }
		set { swap(newValue) }
	}

	/// Modifies the variable. Conforming types may optionally
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

	/// A producer for Signals that will send the wrapped property's current value,
	/// followed by all changes over time, then complete when the wrapped property has
	/// deinitialized.
	public var producer: SignalProducer<Value, NoError> {
		return box.producer
	}

	/// A signal that will send the wrapped property's changes over time, then complete
	/// when the wrapped property has deinitialized.
	public var signal: Signal<Value, NoError> {
		return box.signal
	}

	/// Initializes a property as a read-only view of the given property.
	public init<P: PropertyType where P.Value == Value>(_ property: P) {
		box = AnyPropertyBox(property)
	}

	/// Initializes a property that first takes on `initialValue`, then each value
	/// sent on a signal created by `producer`.
	///
	/// The producer and the signal of the created property would complete only
	/// when the `producer` completes.
	public init(initialValue: Value, producer: SignalProducer<Value, NoError>) {
		self.init(propertyProducer: SignalProducer(value: initialValue).takeUntilReplacement(producer))
	}

	/// Initializes a property that first takes on `initialValue`, then each value
	/// sent on `signal`.
	///
	/// The producer and the signal of the created property would complete only
	/// when the `signal` completes.
	public init(initialValue: Value, signal: Signal<Value, NoError>) {
		self.init(propertyProducer: SignalProducer(value: initialValue).takeUntilReplacement(signal))
	}

	/// Initializes a property from a producer that promises to send at least one
	/// value synchronously in its start handler before sending any subsequent event.
	/// If the producer fails its promise, a fatal error would be raised.
	///
	/// The producer and the signal of the created property would complete only
	/// when the `propertyProducer` completes.
	private init(propertyProducer: SignalProducer<Value, NoError>, capturing closure: (() -> Void)? = nil) {
		let disposable = CompositeDisposable()

		var hasInitialized = false
		var mutableProperty: MutableProperty<Value>?
		weak var weakMutableProperty: MutableProperty<Value>?

		disposable += propertyProducer.start { event in
			switch event {
			case let .Next(value):
				if hasInitialized {
					weakMutableProperty?.value = value
				} else {
					mutableProperty = MutableProperty(value)
					weakMutableProperty = mutableProperty
					hasInitialized = true
				}

			case .Completed, .Interrupted:
				disposable.dispose()

			case let .Failed(error):
				fatalError("Receive unexpected error from a producer of `NoError` type: \(error)")
			}
		}

		if let property = mutableProperty {
			disposable += property.producer.startWithCompleted {
				disposable.dispose()
			}

			box = AnyPropertyBox(property, source: propertyProducer, capturing: closure)
			mutableProperty = nil
		} else {
			fatalError("A producer promised to send at least one value. Received none.")
		}
	}

	public func withValue<Result>(@noescape action: Value throws -> Result) rethrows -> Result {
		return try box.withValue(action)
	}
}

/// A type-erased view to the underlying property which allows mutation of the
/// value.
public class AnyMutableProperty<Value>: MutablePropertyType {
	private let box: AnyPropertyBoxBase<Value>

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	public var producer: SignalProducer<Value, NoError> {
		return box.producer
	}

	/// A signal that will send the property's changes over time, then complete
	/// when the property has deinitialized.
	public var signal: Signal<Value, NoError> {
		return box.signal
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


public func <~ <P: MutablePropertyType, S: SignalType where P.Value == S.Value?, S.Error == NoError>(property: P, signal: S) -> Disposable {
	return property <~ signal.optionalize()
}

public func <~ <P: MutablePropertyType, S: SignalProducerType where P.Value == S.Value?, S.Error == NoError>(property: P, producer: S) -> Disposable {
	return property <~ producer.optionalize()
}

public func <~ <Destination: MutablePropertyType, Source: PropertyType where Destination.Value == Source.Value?>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
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
	override init(_ property: P, source producer: SignalProducer<P.Value, NoError>? = nil, capturing closure: (() -> Void)? = nil) {
		super.init(property, source: producer, capturing: closure)
	}

	override func modify(@noescape action: P.Value throws -> P.Value) rethrows -> P.Value {
		return try property.modify(action)
	}
}

/// The type-erasing box for `AnyProperty`.
private class AnyPropertyBox<P: PropertyType>: AnyPropertyBoxBase<P.Value> {
	let property: P
	let sourceProducer: SignalProducer<P.Value, NoError>?

	/// Wraps a property, and shadows its producer and signal with `source` if supplied.
	init(_ property: P, source producer: SignalProducer<P.Value, NoError>? = nil, capturing closure: (() -> Void)? = nil) {
		self.property = property
		self.sourceProducer = producer
		super.init(capturing: closure)
	}

	override var signal: Signal<P.Value, NoError> {
		if let producer = sourceProducer {
			var extractedSignal: Signal<P.Value, NoError>!
			producer.startWithSignal { signal, _ in extractedSignal = signal }
			return extractedSignal
		} else {
			return property.signal
		}
	}

	override var producer: SignalProducer<P.Value, NoError> {
		return sourceProducer ?? property.producer
	}

	override func withValue<Result>(@noescape action: P.Value throws -> Result) rethrows -> Result {
		return try property.withValue(action)
	}
}

/// The base class of the type-erasing boxes.
private class AnyPropertyBoxBase<Value>: PropertyType {
	let capturingClosure: (() -> Void)?

	init(capturing closure: (() -> Void)?) {
		capturingClosure = closure
	}

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