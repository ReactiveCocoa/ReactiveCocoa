import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
public protocol PropertyType {
	associatedtype Value

	/// The current value of the property.
	var value: Value { get }

	/// A producer for signals that sends the property's current value,
	/// followed by all changes over time. It completes when the property
	/// has deinitialized, or has no further change.
	var producer: SignalProducer<Value, NoError> { get }

	/// A signal that will send the property's changes over time. It
	/// completes when the property has deinitialized, or has no further
	/// change.
	var signal: Signal<Value, NoError> { get }
}

/// Represents an observable property that can be mutated directly.
///
/// Only classes can conform to this protocol, because instances must support
/// weak references (and value types currently do not).
public protocol MutablePropertyType: class, PropertyType {
	/// The current value of the property.
	var value: Value { get set }
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
		return AnyProperty(transforming: self, using: transform)
	}

	/// Lifts a binary SignalProducer operator to operate upon PropertyType instead.
	@warn_unused_result(message="Did you forget to use the composed property?")
	private func lift<P: PropertyType, U>(transform: SignalProducer<Value, NoError> -> SignalProducer<P.Value, NoError> -> SignalProducer<U, NoError>) -> P -> AnyProperty<U> {
		return { otherProperty in
			return AnyProperty(transformingFirst: self, second: otherProperty, using: transform)
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

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType>(a: A, _ b: B) -> AnyProperty<(A.Value, B.Value)> {
	return a.combineLatest(with: b)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType>(a: A, _ b: B, _ c: C) -> AnyProperty<(A.Value, B.Value, C.Value)> {
	return combineLatest(a, b)
		.combineLatest(with: c)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType>(a: A, _ b: B, _ c: C, _ d: D) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value)> {
	return combineLatest(a, b, c)
		.combineLatest(with: d)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
	return combineLatest(a, b, c, d)
		.combineLatest(with: e)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
	return combineLatest(a, b, c, d, e)
		.combineLatest(with: f)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
	return combineLatest(a, b, c, d, e, f)
		.combineLatest(with: g)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
	return combineLatest(a, b, c, d, e, f, g)
		.combineLatest(with: h)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
	return combineLatest(a, b, c, d, e, f, g, h)
		.combineLatest(with: i)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType, J: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
	return combineLatest(a, b, c, d, e, f, g, h, i)
		.combineLatest(with: j)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatest(with:)`. Returns nil if the sequence is empty.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<S: SequenceType where S.Generator.Element: PropertyType>(properties: S) -> AnyProperty<[S.Generator.Element.Value]>? {
	var generator = properties.generate()
	if let first = generator.next() {
		let initial = first.map { [$0] }
		return GeneratorSequence(generator).reduce(initial) { property, next in
			property.combineLatest(with: next).map { $0.0 + [$0.1] }
		}
	}

	return nil
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType>(a: A, _ b: B) -> AnyProperty<(A.Value, B.Value)> {
	return a.zip(with: b)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType>(a: A, _ b: B, _ c: C) -> AnyProperty<(A.Value, B.Value, C.Value)> {
	return zip(a, b)
		.zip(with: c)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType>(a: A, _ b: B, _ c: C, _ d: D) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value)> {
	return zip(a, b, c)
		.zip(with: d)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
	return zip(a, b, c, d)
		.zip(with: e)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
	return zip(a, b, c, d, e)
		.zip(with: f)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
	return zip(a, b, c, d, e, f)
		.zip(with: g)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
	return zip(a, b, c, d, e, f, g)
		.zip(with: h)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
	return zip(a, b, c, d, e, f, g, h)
		.zip(with: i)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType, J: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
	return zip(a, b, c, d, e, f, g, h, i)
		.zip(with: j)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`. Returns nil if the sequence is empty.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<S: SequenceType where S.Generator.Element: PropertyType>(properties: S) -> AnyProperty<[S.Generator.Element.Value]>? {
	var generator = properties.generate()
	if let first = generator.next() {
		let initial = first.map { [$0] }
		return GeneratorSequence(generator).reduce(initial) { property, next in
			property.zip(with: next).map { $0.0 + [$0.1] }
		}
	}

	return nil
}

/// A read-only, type-erased view of a property.
public struct AnyProperty<Value>: PropertyType {
	private let capturingClosure: (() -> Void)?

	private let _value: () -> Value
	private let _producer: () -> SignalProducer<Value, NoError>
	private let _signal: () -> Signal<Value, NoError>

	/// The current value of the property.
	public var value: Value {
		return _value()
	}

	/// A producer for Signals that will send the wrapped property's current value,
	/// followed by all changes over time, then complete when the wrapped property has
	/// deinitialized.
	public var producer: SignalProducer<Value, NoError> {
		return _producer()
	}

	/// A signal that will send the wrapped property's changes over time, then complete
	/// when the wrapped property has deinitialized.
	public var signal: Signal<Value, NoError> {
		return _signal()
	}

	/// Initializes a property as a read-only view of the given property.
	public init<P: PropertyType where P.Value == Value>(_ property: P) {
		capturingClosure = AnyProperty.capture(property)
		_value = { property.value }
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

	/// Initializes a property by applying the unary `SignalProducer` transform on
	/// `property`. The resulting property captures `property`.
	private init<P: PropertyType>(transforming property: P, @noescape using transform: SignalProducer<P.Value, NoError> -> SignalProducer<Value, NoError>) {
		self.init(propertyProducer: transform(property.producer),
		          capturing: AnyProperty.capture(property))
	}

	/// Initializes a property by applying the binary `SignalProducer` transform on
	/// `property` and `anotherProperty`. The resulting property captures `property`
	/// and `anotherProperty`.
	private init<P1: PropertyType, P2: PropertyType>(transformingFirst property: P1, second anotherProperty: P2, @noescape using transform: SignalProducer<P1.Value, NoError> -> SignalProducer<P2.Value, NoError> -> SignalProducer<Value, NoError>) {
		self.init(propertyProducer: transform(property.producer)(anotherProperty.producer),
		          capturing: AnyProperty.capture(property, anotherProperty))
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

			capturingClosure = closure
			_value = { property.value }
			_producer = { propertyProducer }
			_signal = {
				var extractedSignal: Signal<Value, NoError>!
				propertyProducer.startWithSignal { signal, _ in extractedSignal = signal }
				return extractedSignal
			}
			mutableProperty = nil
		} else {
			fatalError("A producer promised to send at least one value. Received none.")
		}
	}

	/// Check if `property` is an `AnyProperty` and has already captured its sources
	/// using a closure. Returns that closure if it does. Otherwise, returns a closure
	/// which captures `property`.
	private static func capture<P: PropertyType>(property: P) -> (() -> Void) {
		if let property = property as? AnyProperty<P.Value>, closure = property.capturingClosure {
			return closure
		} else {
			return { property }
		}
	}

	/// Applies `capture(_:)` on the supplied properties, and returns a closure that
	/// captures the resulting closures.
	private static func capture<P1: PropertyType, P2: PropertyType>(firstProperty: P1, _ secondProperty: P2) -> (() -> Void) {
		let firstClosure = capture(firstProperty)
		let secondClosure = capture(secondProperty)
		return { _ = (firstClosure, secondClosure) }
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
	/// Setting this to a new value will notify all observers of `signal`, or signals
	/// created using `producer`.
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

	/// Initializes the property with the given value to start.
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
	/// Returns the old value.
	public func swap(newValue: Value) -> Value {
		return modify { _ in newValue }
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