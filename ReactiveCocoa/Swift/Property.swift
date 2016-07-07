import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
///
/// Only classes can conform to this protocol, because having a signal
/// for changes over time implies the origin must have a unique identity.
public protocol PropertyType: class {
	associatedtype Value

	/// The current value of the property.
	var value: Value { get }

	/// The values producer of the property.
	///
	/// It produces a signal that sends the property's current value,
	/// followed by all changes over time. It completes when the property
	/// has deinitialized, or has no further change.
	var values: SignalProducer<Value, NoError> { get }

	/// The change producer of the property.
	///
	/// It produces a signal that sends the property's changes over time. It
	/// completes when the property has deinitialized, or has no further
	/// change.
	var changes: SignalProducer<Value, NoError> { get }

	/// The property sources to be captured.
	///
	/// A default implementation is provided for this requirement, and it is
	/// intended to be overriden by only `AnyProperty`.
	var sources: [AnyObject] { get }
}

/// Represents an observable property that can be mutated directly.
public protocol MutablePropertyType: PropertyType {
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
	public var sources: [AnyObject] {
		/// Generally, only `Property` would have non-`self` sources to be captured.
		return [self]
	}

	/// Lifts a unary SignalProducer operator to operate upon PropertyType instead.
	@warn_unused_result(message="Did you forget to use the composed property?")
	private func lift<U>(@noescape transform: SignalProducer<Value, NoError> -> SignalProducer<U, NoError>) -> AnyProperty<U> {
		return AnyProperty(self, transform: transform)
	}

	/// Lifts a binary SignalProducer operator to operate upon PropertyType instead.
	@warn_unused_result(message="Did you forget to use the composed property?")
	private func lift<P: PropertyType, U>(transform: SignalProducer<Value, NoError> -> SignalProducer<P.Value, NoError> -> SignalProducer<U, NoError>) -> P -> AnyProperty<U> {
		return { otherProperty in
			return AnyProperty(self, otherProperty, transform: transform)
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
	public func combineLatestWith<P: PropertyType>(other: P) -> AnyProperty<(Value, P.Value)> {
		return lift(SignalProducer.combineLatestWith)(other)
	}

	/// Zips the current value and the subsequent values of two `Property`s in
	/// the manner described by `Signal.zipWith`.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func zipWith<P: PropertyType>(other: P) -> AnyProperty<(Value, P.Value)> {
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

extension PropertyType where Value: PropertyType {
	/// Flattens the inner properties sent upon `self` (into a single property),
	/// according to the semantics of the given strategy.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func flatten(strategy: FlattenStrategy) -> AnyProperty<Value.Value> {
		return lift { $0.flatMap(strategy) { $0.values } }
	}
}

extension PropertyType {
	/// Maps each property from `self` to a new property, then flattens the
	/// resulting properties (into a single property), according to the
	/// semantics of the given strategy.
	@warn_unused_result(message="Did you forget to use the composed property?")
	public func flatMap<P: PropertyType>(strategy: FlattenStrategy, transform: Value -> P) -> AnyProperty<P.Value> {
		return lift { $0.flatMap(strategy) { transform($0).values } }
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
	return a.combineLatestWith(b)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType>(a: A, _ b: B, _ c: C) -> AnyProperty<(A.Value, B.Value, C.Value)> {
	return combineLatest(a, b)
		.combineLatestWith(c)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType>(a: A, _ b: B, _ c: C, _ d: D) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value)> {
	return combineLatest(a, b, c)
		.combineLatestWith(d)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
	return combineLatest(a, b, c, d)
		.combineLatestWith(e)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
	return combineLatest(a, b, c, d, e)
		.combineLatestWith(f)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
	return combineLatest(a, b, c, d, e, f)
		.combineLatestWith(g)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
	return combineLatest(a, b, c, d, e, f, g)
		.combineLatestWith(h)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
	return combineLatest(a, b, c, d, e, f, g, h)
		.combineLatestWith(i)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatest(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType, J: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
	return combineLatest(a, b, c, d, e, f, g, h, i)
		.combineLatestWith(j)
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
			property.combineLatestWith(next).map { $0.0 + [$0.1] }
		}
	}

	return nil
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType>(a: A, _ b: B) -> AnyProperty<(A.Value, B.Value)> {
	return a.zipWith(b)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType>(a: A, _ b: B, _ c: C) -> AnyProperty<(A.Value, B.Value, C.Value)> {
	return zip(a, b)
		.zipWith(c)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType>(a: A, _ b: B, _ c: C, _ d: D) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value)> {
	return zip(a, b, c)
		.zipWith(d)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
	return zip(a, b, c, d)
		.zipWith(e)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
	return zip(a, b, c, d, e)
		.zipWith(f)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
	return zip(a, b, c, d, e, f)
		.zipWith(g)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
	return zip(a, b, c, d, e, f, g)
		.zipWith(h)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
	return zip(a, b, c, d, e, f, g, h)
		.zipWith(i)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zip(with:)`.
@warn_unused_result(message="Did you forget to use the property?")
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType, J: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
	return zip(a, b, c, d, e, f, g, h, i)
		.zipWith(j)
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
			property.zipWith(next).map { $0.0 + [$0.1] }
		}
	}

	return nil
}

/// A read-only property that allows observation of its changes.
public class AnyProperty<Value>: PropertyType {
	public let sources: [AnyObject]

	private let _value: () -> Value
	private let _values: SignalProducer<Value, NoError>
	private let _changes: SignalProducer<Value, NoError>


	/// The current value of the property.
	public var value: Value {
		return _value()
	}

	/// A producer for Signals that will send the wrapped property's current value,
	/// followed by all changes over time, then complete when the wrapped property has
	/// deinitialized.
	public var values: SignalProducer<Value, NoError> {
		return _values
	}

	/// A signal that will send the wrapped property's changes over time, then complete
	/// when the wrapped property has deinitialized.
	///
	/// It is strongly discouraged to use `signal` on any transformed property.
	public var changes: SignalProducer<Value, NoError> {
		return _changes
	}

	/// Initializes a property as a read-only view of the given property.
	public init<P: PropertyType where P.Value == Value>(_ property: P) {
		sources = property.sources
		_value = { property.value }
		_values = property.values
		_changes = property.changes
	}

	/// Initializes a property that first takes on `initialValue`, then each value
	/// sent on a signal created by `producer`.
	public convenience init(initialValue: Value, producer: SignalProducer<Value, NoError>) {
		self.init(propertyProducer: producer.prefix(value: initialValue),
		          capturing: [])
	}

	/// Initializes a property that first takes on `initialValue`, then each value
	/// sent on `signal`.
	public convenience init(initialValue: Value, signal: Signal<Value, NoError>) {
		self.init(propertyProducer: SignalProducer(signal: signal).prefix(value: initialValue),
		          capturing: [])
	}

	/// Initializes a property by applying the unary `SignalProducer` transform on
	/// `property`. The resulting property captures `property`.
	private convenience init<P: PropertyType>(_ property: P, @noescape transform: SignalProducer<P.Value, NoError> -> SignalProducer<Value, NoError>) {
		self.init(propertyProducer: transform(property.values),
		          capturing: property.sources)
	}

	/// Initializes a property by applying the binary `SignalProducer` transform on
	/// `property` and `anotherProperty`. The resulting property captures `property`
	/// and `anotherProperty`.
	private convenience init<P1: PropertyType, P2: PropertyType>(_ firstProperty: P1, _ secondProperty: P2, @noescape transform: SignalProducer<P1.Value, NoError> -> SignalProducer<P2.Value, NoError> -> SignalProducer<Value, NoError>) {
		self.init(propertyProducer: transform(firstProperty.values)(secondProperty.values),
		          capturing: firstProperty.sources + secondProperty.sources)
	}

	/// Initializes a property from a producer that promises to send at least one
	/// value synchronously in its start handler before sending any subsequent event.
	/// If the producer fails its promise, a fatal error would be raised.
	///
	/// The producer and the signal of the created property would complete only
	/// when the `propertyProducer` completes.
	private init(propertyProducer: SignalProducer<Value, NoError>, capturing propertySources: [AnyObject]) {
		// The relay would be indirectly retained by `AnyProperty` and also every produced
		/// signal from this relay through `scopedDisposable`.

		// A disposable that holds a reference to the relay, and the observer disposable
		// used for interrupting the started `propertyProducer`.
		let relayDisposable = CompositeDisposable()

		// A disposable that wraps the `relayDisposable`. All the consumers of the relay
		// would retain this disposable, so that when all parties go out of scope, the
		// started `propertyProducer` can be interrupted.
		let scopedDisposable = ScopedDisposable(relayDisposable)
		sources = propertySources + [scopedDisposable]

		let relay = MutableProperty<Value?>(nil)
		relayDisposable += { _ = relay }

		relayDisposable += propertyProducer.start { [weak relay] event in
			switch event {
			case let .Next(newValue):
				relay?.value = newValue

			case .Completed, .Interrupted:
				relayDisposable.dispose()

			case let .Failed(error):
				fatalError("Receive unexpected error from a producer of `NoError` type: \(error)")
			}
		}

		guard relay.value != nil else {
			fatalError("A producer promised to send at least one value. Received none.")
		}

		func prepareRelayProducer(producer: SignalProducer<Value?, NoError>) -> SignalProducer<Value, NoError> {
			return SignalProducer { observer, producerDisposable in
				producer.startWithSignal { signal, signalDisposable in
					producerDisposable += { _ = scopedDisposable }
					producerDisposable += signalDisposable
					producerDisposable += signal.observe { event in
						observer.action(event.map { $0! })
					}
				}
			}
		}

		_value = { relay.value! }
		_values = prepareRelayProducer(relay.values)
		_changes = prepareRelayProducer(relay.changes)
	}
}

/// A property that never changes.
public class ConstantProperty<Value>: PropertyType {
	public let value: Value
	public let values: SignalProducer<Value, NoError>
	public let changes: SignalProducer<Value, NoError>

	/// Initializes the property to have the given value.
	public init(_ value: Value) {
		self.value = value
		self.values = SignalProducer(value: value)
		self.changes = .interrupted
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

	/// The box of the underlying storage, which may outlive the property
	/// if a returned producer is being retained.
	private let box: Box<Value>

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
	private let signal: Signal<Value, NoError>

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	public var values: SignalProducer<Value, NoError> {
		return SignalProducer { [box, weak self] producerObserver, producerDisposable in
			if let strongSelf = self {
				strongSelf.withValue { value in
					producerObserver.sendNext(value)
					producerDisposable += strongSelf.signal.observe(producerObserver)
				}
			} else {
				/// As the setter would have been deinitialized with the property,
				/// the underlying storage would be immutable, and locking is no longer necessary.
				producerObserver.sendNext(box.value)
				producerObserver.sendCompleted()
			}
		}
	}

	/// A producer that will send the property's changes over time,
	/// then complete when the property has deinitialized.
	public var changes: SignalProducer<Value, NoError> {
		return SignalProducer(signal: signal)
	}

	/// Initializes the property with the given value to start.
	public init(_ initialValue: Value) {
		lock = NSRecursiveLock()
		lock.name = "org.reactivecocoa.ReactiveCocoa.MutableProperty"

		box = Box(initialValue)
		(signal, observer) = Signal.pipe()
	}

	/// Atomically replaces the contents of the variable.
	///
	/// Returns the old value.
	public func swap(newValue: Value) -> Value {
		return modify { $0 = newValue }
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	public func modify(@noescape action: (inout Value) throws -> Void) rethrows -> Value {
		return try withValue { value in
			try action(&box.value)
			observer.sendNext(box.value)
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

		return try action(box.value)
	}

	deinit {
		observer.sendCompleted()
	}
}

private class Box<Value> {
	var value: Value

	init(_ value: Value) {
		self.value = value
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
	disposable += property.values.startWithCompleted {
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

			disposable += property.values.startWithCompleted {
				disposable.dispose()
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
	return destinationProperty <~ sourceProperty.values
}

/// Binds `destinationProperty` to the latest values of `sourceProperty`.
///
/// The binding will automatically terminate when either property is
/// deinitialized.
public func <~ <Destination: MutablePropertyType, Source: PropertyType where Source.Value == Destination.Value>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.values
}
