import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
public protocol PropertyProtocol {
	associatedtype Value

	/// The current value of the property.
	var value: Value { get }

	/// The values producer of the property.
	///
	/// It produces a signal that sends the property's current value,
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
public protocol MutablePropertyProtocol: class, PropertyProtocol {
	/// The current value of the property.
	var value: Value { get set }
}

/// Protocol composition operators
///
/// The producer and the signal of transformed properties would complete
/// only when its source properties have deinitialized.
///
/// A composed property would retain its ultimate source, but not
/// any intermediate property during the composition.
extension PropertyProtocol {
	/// Lifts a unary SignalProducer operator to operate upon PropertyProtocol instead.
	private func lift<U>( _ transform: @noescape (SignalProducer<Value, NoError>) -> SignalProducer<U, NoError>) -> AnyProperty<U> {
		return AnyProperty(self, transform: transform)
	}

	/// Lifts a binary SignalProducer operator to operate upon PropertyProtocol instead.
	private func lift<P: PropertyProtocol, U>(_ transform: @noescape (SignalProducer<Value, NoError>) -> (SignalProducer<P.Value, NoError>) -> SignalProducer<U, NoError>) -> @noescape (P) -> AnyProperty<U> {
		return { otherProperty in
			return AnyProperty(self, otherProperty, transform: transform)
		}
	}

	/// Maps the current value and all subsequent values to a new property.
	///
	/// - parameters:
	///   - transform: A closure that will map the current `value` of this
	///                `Property` to a new value.
	///
	/// - returns: A new instance of `AnyProperty` who's holds a mapped value
	///            from `self`.
	public func map<U>(_ transform: (Value) -> U) -> AnyProperty<U> {
		return lift { $0.map(transform) }
	}

	/// Combines the current value and the subsequent values of two `Property`s in
	/// the manner described by `Signal.combineLatestWith:`.
	///
	/// - parameters:
	///   - other: A property to combine `self`'s value with.
	///
	/// - returns: A property that holds a tuple containing values of `self` and
	///            the given property.
	public func combineLatest<P: PropertyProtocol>(with other: P) -> AnyProperty<(Value, P.Value)> {
		return lift(SignalProducer.combineLatest(with:))(other)
	}

	/// Zips the current value and the subsequent values of two `Property`s in
	/// the manner described by `Signal.zipWith`.
	///
	/// - parameters:
	///   - other: A property to zip `self`'s value with.
	///
	/// - returns: A property that holds a tuple containing values of `self` and
	///            the given property.
	public func zip<P: PropertyProtocol>(with other: P) -> AnyProperty<(Value, P.Value)> {
		return lift(SignalProducer.zip(with:))(other)
	}

	/// Forward events from `self` with history: values of the returned property
	/// are a tuple whose first member is the previous value and whose second
	/// member is the current value. `initial` is supplied as the first member
	/// when `self` sends its first value.
	///
	/// - parameters:
	///   - initial: A value that will be combined with the first value sent by
	///              `self`.
	///
	/// - returns: A property that holds tuples that contain previous and
	///            current values of `self`.
	public func combinePrevious(initial: Value) -> AnyProperty<(Value, Value)> {
		return lift { $0.combinePrevious(initial) }
	}

	/// Forward only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value.
	///
	/// - parameters:
	///   - isRepeat: A predicate to determine if the two given values are equal.
	///
	/// - returns: A property that does not emit events for two equal values
	///            sequentially.
	public func skipRepeats(_ isRepeat: (Value, Value) -> Bool) -> AnyProperty<Value> {
		return lift { $0.skipRepeats(isRepeat) }
	}
}

extension PropertyProtocol where Value: Equatable {
	/// Forward only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value.
	///
	/// - returns: A property that does not emit events for two equal values
	///            sequentially.
	public func skipRepeats() -> AnyProperty<Value> {
		return lift { $0.skipRepeats() }
	}
}

extension PropertyProtocol where Value: PropertyProtocol {
	/// Flattens the inner property held by `self` (into a single property of
	/// values), according to the semantics of the given strategy.
	///
	/// - parameters:
	///   - strategy: The preferred flatten strategy.
	///
	/// - returns: A property that sends the values of its inner properties.
	public func flatten(_ strategy: FlattenStrategy) -> AnyProperty<Value.Value> {
		return lift { $0.flatMap(strategy) { $0.producer } }
	}
}

extension PropertyProtocol {
	/// Maps each property from `self` to a new property, then flattens the
	/// resulting properties (into a single property), according to the
	/// semantics of the given strategy.
	///
	/// - parameters:
	///   - strategy: The preferred flatten strategy.
	///   - transform: The transform to be applied on `self` before flattening.
	///
	/// - returns: A property that sends the values of its inner properties.
	public func flatMap<P: PropertyProtocol>(_ strategy: FlattenStrategy, transform: (Value) -> P) -> AnyProperty<P.Value> {
		return lift { $0.flatMap(strategy) { transform($0).producer } }
	}

	/// Forward only those values from `self` that have unique identities across
	/// the set of all values that have been held.
	///
	/// - note: This causes the identities to be retained to check for 
	///         uniqueness.
	///
	/// - parameters:
	///   - transform: A closure that accepts a value and returns identity
	///                value.
	///
	/// - returns: A property that sends unique values during its lifetime.
	public func uniqueValues<Identity: Hashable>(_ transform: (Value) -> Identity) -> AnyProperty<Value> {
		return lift { $0.uniqueValues(transform) }
	}
}

extension PropertyProtocol where Value: Hashable {
	/// Forwards only those values from `self` that are unique across the set of
	/// all values that have been seen.
	///
	/// - note: This causes the identities to be retained to check for uniqueness.
	///         Providing a function that returns a unique value for each sent
	///         value can help you reduce the memory footprint.
	///
	/// - returns: A property that sends unique values during its lifetime.
	public func uniqueValues() -> AnyProperty<Value> {
		return lift { $0.uniqueValues() }
	}
}

extension PropertyProtocol {
	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B) -> AnyProperty<(A.Value, B.Value)> {
		return a.combineLatest(with: b)
	}

	/// Combines the values of all the given properties, in the manner described 
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C) -> AnyProperty<(A.Value, B.Value, C.Value)> {
		return combineLatest(a, b)
			.combineLatest(with: c)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described 
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value)> {
		return combineLatest(a, b, c)
			.combineLatest(with: d)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described 
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
		return combineLatest(a, b, c, d)
			.combineLatest(with: e)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described 
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
		return combineLatest(a, b, c, d, e)
			.combineLatest(with: f)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described 
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
		return combineLatest(a, b, c, d, e, f)
			.combineLatest(with: g)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described 
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
		return combineLatest(a, b, c, d, e, f, g)
			.combineLatest(with: h)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described 
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
		return combineLatest(a, b, c, d, e, f, g, h)
			.combineLatest(with: i)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described 
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol, J: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
		return combineLatest(a, b, c, d, e, f, g, h, i)
			.combineLatest(with: j)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`. Returns nil if the sequence is empty.
	public static func combineLatest<S: Sequence where S.Iterator.Element: PropertyProtocol>(_ properties: S) -> AnyProperty<[S.Iterator.Element.Value]>? {
		var generator = properties.makeIterator()
		if let first = generator.next() {
			let initial = first.map { [$0] }
			return IteratorSequence(generator).reduce(initial) { property, next in
				property.combineLatest(with: next).map { $0.0 + [$0.1] }
			}
		}

		return nil
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B) -> AnyProperty<(A.Value, B.Value)> {
		return a.zip(with: b)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C) -> AnyProperty<(A.Value, B.Value, C.Value)> {
		return zip(a, b)
			.zip(with: c)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value)> {
		return zip(a, b, c)
			.zip(with: d)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
		return zip(a, b, c, d)
			.zip(with: e)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
		return zip(a, b, c, d, e)
			.zip(with: f)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
		return zip(a, b, c, d, e, f)
			.zip(with: g)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
		return zip(a, b, c, d, e, f, g)
			.zip(with: h)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
		return zip(a, b, c, d, e, f, g, h)
			.zip(with: i)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol, J: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
		return zip(a, b, c, d, e, f, g, h, i)
			.zip(with: j)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`. Returns nil if the sequence is empty.
	public static func zip<S: Sequence where S.Iterator.Element: PropertyProtocol>(_ properties: S) -> AnyProperty<[S.Iterator.Element.Value]>? {
		var generator = properties.makeIterator()
		if let first = generator.next() {
			let initial = first.map { [$0] }
			return IteratorSequence(generator).reduce(initial) { property, next in
				property.zip(with: next).map { $0.0 + [$0.1] }
			}
		}
		
		return nil
	}
}

/// A read-only property that allows observation of its changes.
public struct AnyProperty<Value>: PropertyProtocol {
	private let sources: [Any]

	private let _value: () -> Value
	private let _producer: () -> SignalProducer<Value, NoError>
	private let _signal: () -> Signal<Value, NoError>

	/// The current value of the property.
	public var value: Value {
		return _value()
	}

	/// A producer for Signals that will send the wrapped property's current
	/// value, followed by all changes over time, then complete when the wrapped
	/// property has deinitialized.
	public var producer: SignalProducer<Value, NoError> {
		return _producer()
	}

	/// A signal that will send the wrapped property's changes over time, then
	/// complete when the wrapped property has deinitialized.
	public var signal: Signal<Value, NoError> {
		return _signal()
	}

	/// Initialize a property as a read-only view of the given property.
	///
	/// - parameters:
	///   - property: A property to read as this property's own value.
	public init<P: PropertyProtocol where P.Value == Value>(_ property: P) {
		sources = [property]

		_value = { property.value }
		_producer = { property.producer }
		_signal = { property.signal }
	}

	/// Initialize a property that first takes on `initial`, then each value
	/// sent on a signal created by `producer`.
	///
	/// - parameters:
	///   - initialValue: Starting value for the property.
	///   - producer: A producer that will start immediately and send values to
	///               the property.
	public init(initial: Value, then producer: SignalProducer<Value, NoError>) {
		self.init(unsafeProducer: producer.prefix(value: initial),
		          capturing: [])
	}

	/// Initialize a property that first takes on `initial`, then each value
	/// sent on `signal`.
	///
	/// - parameters:
	///   - initialValue: Starting value for the property.
	///   - signal: A signal that will send values to the property.
	public init(initial: Value, then signal: Signal<Value, NoError>) {
		self.init(unsafeProducer: SignalProducer(signal: signal).prefix(value: initial),
		          capturing: [])
	}

	/// Initialize a property by applying the unary `SignalProducer` transform
	/// on `property`. The resulting property captures `property`.
	///
	/// - parameters:
	///   - property: The source property.
	///   - signal: A unary `SignalProducer` transform to be applied on
	///     `property`.
	private init<P: PropertyProtocol>(_ property: P, transform: @noescape (SignalProducer<P.Value, NoError>) -> SignalProducer<Value, NoError>) {
		self.init(unsafeProducer: transform(property.producer),
		          capturing: AnyProperty.capture(property))
	}

	/// Initialize a property by applying the binary `SignalProducer` transform
	/// on `firstProperty` and `secondProperty`. The resulting property captures
	/// the two property sources.
	///
	/// - parameters:
	///   - firstProperty: The first source property.
	///   - secondProperty: The first source property.
	///   - signal: A binary `SignalProducer` transform to be applied on
	///             `firstProperty` and `secondProperty`.
	private init<P1: PropertyProtocol, P2: PropertyProtocol>(_ firstProperty: P1, _ secondProperty: P2, transform: @noescape (SignalProducer<P1.Value, NoError>) -> (SignalProducer<P2.Value, NoError>) -> SignalProducer<Value, NoError>) {
		self.init(unsafeProducer: transform(firstProperty.producer)(secondProperty.producer),
		          capturing: AnyProperty.capture(firstProperty) + AnyProperty.capture(secondProperty))
	}

	/// Initialize a property from a producer that promises to send at least one
	/// value synchronously in its start handler before sending any subsequent
	/// event.
	///
	/// - important: The producer and the signal of the created property would
	///              complete only when the `unsafeProducer` completes.
	///
	/// - warning: If the producer fails its promise, a fatal error would be
	///            raised.
	///
	/// - parameters:
	///   - unsafeProducer: The composed producer for creating the property.
	///   - sources: The property sources to be captured.
	private init(unsafeProducer: SignalProducer<Value, NoError>, capturing propertySources: [Any]) {
		// A relay that provides a single source of truth for this composed
		// property.
		let relay = MutableProperty<Value?>(nil)

		// A disposable that causes the relay to emit a `completed` event.
		//
		// It is disposed of when the upstream emits a terminating event, or
		// when `scopeDisposable` is released by the last consumer.
		let relayDisposable = CompositeDisposable()
		relayDisposable += { _ = relay }

		// A disposable that tracks the active consumers of the relay.
		//
		// This property, its lazily initialized signal and its producer
		// would retain this disposable to keep the relay alive.
		//
		// When the last consumer releases this disposable, the wrapped
		// `relayDisposable` would be disposed of to clean up all resources.
		//
		// Note that it is possible of `relayDisposable` to be disposed of
		// ahead of this disposable, in the case of an upstream terminating
		// event.
		let scopedDisposable = ScopedDisposable(relayDisposable)

		// Records the sources of this property.
		sources = propertySources + [scopedDisposable]

		// Starts forwarding values from the upstream to the relay.
		relayDisposable += unsafeProducer.start { [weak relay] event in
			switch event {
			case let .next(newValue):
				relay?.value = newValue

			case .completed, .interrupted:
				relayDisposable.dispose()

			case let .failed(error):
				fatalError("Receive unexpected error from a producer of `NoError` type: \(error)")
			}
		}

		guard relay.value != nil else {
			fatalError("A producer promised to send at least one value. Received none.")
		}

		func prepareRelayProducer(_ producer: SignalProducer<Value?, NoError>) -> SignalProducer<Value, NoError> {
			return SignalProducer { observer, producerDisposable in
				producer.startWithSignal { signal, signalDisposable in
					producerDisposable += signalDisposable
					prepareRelaySignal(signal).observe(observer)
				}
			}
		}

		func prepareRelaySignal(_ signal: Signal<Value?, NoError>) -> Signal<Value, NoError> {
			return Signal { observer in
				let signalDisposable = CompositeDisposable()
				signalDisposable += { _ = scopedDisposable }
				signalDisposable += signal.observe { event in
					observer.action(event.map { $0! })
				}
				return signalDisposable
			}
		}

		_value = { relay.value! }
		_producer = { prepareRelayProducer(relay.producer) }

		// Lazily initializes the signal of this composed property.
		//
		// The created signal would retain `scopedDisposable` to keep the relay alive,
		// thus inevitably binding the relay to the lifetime of the upstream for good.
		let atomicSignal = Atomic<Signal<Value, NoError>?>(nil)
		_signal = {
			var signal: Signal<Value, NoError>!
			atomicSignal.modify { innerSignal in
				if signal == nil {
					innerSignal = prepareRelaySignal(relay.signal)
				}
				signal = innerSignal
			}
			return signal
		}
	}

	/// Inspect if `property` is an `AnyProperty` and has already captured its
	/// sources using a closure. Returns that closure if it does. Otherwise,
	/// returns a closure which captures `property`.
	///
	/// - parameters:
	///   - property: The property to be insepcted.
	private static func capture<P: PropertyProtocol>(_ property: P) -> [Any] {
		if let property = property as? AnyProperty<P.Value> {
			return property.sources
		} else {
			return [property]
		}
	}
}

/// A property that never changes.
public struct ConstantProperty<Value>: PropertyProtocol {

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

/// A mutable property of type `Value` that allows observation of its changes.
///
/// Instances of this class are thread-safe.
public final class MutableProperty<Value>: MutablePropertyProtocol {
	private let observer: Signal<Value, NoError>.Observer

	/// Need a recursive lock around `value` to allow recursive access to
	/// `value`. Note that recursive sets will still deadlock because the
	/// underlying producer prevents sending recursive events.
	private let lock: RecursiveLock

	/// The box of the underlying storage, which may outlive the property
	/// if a returned producer is being retained.
	private let box: Box<Value>

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all observers of `signal`, or
	/// signals created using `producer`.
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

	/// Initializes a mutable property that first takes on `initialValue`
	///
	/// - parameters:
	///   - initialValue: Starting value for the mutable property.
	public init(_ initialValue: Value) {
		lock = RecursiveLock()
		lock.name = "org.reactivecocoa.ReactiveCocoa.MutableProperty"

		box = Box(initialValue)
		(signal, observer) = Signal.pipe()
	}

	/// Atomically replaces the contents of the variable.
	///
	/// - parameters:
	///   - newValue: New property value.
	///
	/// - returns: The previous property value.
	@discardableResult
	public func swap(_ newValue: Value) -> Value {
		return modify { $0 = newValue }
	}

	/// Atomically modifies the variable.
	///
	/// - parameters:
	///   - action: A closure that accepts old property value and returns a new
	///             property value.
	/// - returns: The previous property value.
	@discardableResult
	public func modify(_ action: @noescape (inout Value) throws -> Void) rethrows -> Value {
		return try withValue { value in
			try action(&box.value)
			observer.sendNext(box.value)
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
	@discardableResult
	public func withValue<Result>(action: @noescape (Value) throws -> Result) rethrows -> Result {
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
/// - note: The binding will automatically terminate when the property is
///         deinitialized, or when the signal sends a `completed` event.
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
/// // `completed` event.
/// disposable.dispose()
/// ````
///
/// - parameters:
///   - property: A property to bind to.
///   - signal: A signal to bind.
///
/// - returns: A disposable that can be used to terminate binding before the
///            deinitialization of property or signal's `completed` event.
@discardableResult
public func <~ <P: MutablePropertyProtocol>(property: P, signal: Signal<P.Value, NoError>) -> Disposable {
	let disposable = CompositeDisposable()
	disposable += property.producer.startWithCompleted {
		disposable.dispose()
	}

	disposable += signal.observe { [weak property] event in
		switch event {
		case let .next(value):
			property?.value = value
		case .completed:
			disposable.dispose()
		case .failed, .interrupted:
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
/// // signal's `completed` event.
/// disposable.dispose()
/// ````
///
/// - note: The binding will automatically terminate when the property is 
///         deinitialized, or when the created producer sends a `completed` 
///         event.
///
/// - parameters:
///   - property: A property to bind to.
///   - producer: A producer to bind.
///
/// - returns: A disposable that can be used to terminate binding before the
///            deinitialization of property or producer's `completed` event.
@discardableResult
public func <~ <P: MutablePropertyProtocol>(property: P, producer: SignalProducer<P.Value, NoError>) -> Disposable {
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

/// Binds a signal to a property, updating the property's value to the latest
/// value sent by the signal.
///
/// - note: The binding will automatically terminate when the property is
///         deinitialized, or when the signal sends a `completed` event.
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
/// // `completed` event.
/// disposable.dispose()
/// ````
///
/// - parameters:
///   - property: A property to bind to.
///   - signal: A signal to bind.
///
/// - returns: A disposable that can be used to terminate binding before the
///            deinitialization of property or signal's `completed` event.
@discardableResult
public func <~ <P: MutablePropertyProtocol, S: SignalProtocol where P.Value == S.Value?, S.Error == NoError>(property: P, signal: S) -> Disposable {
	return property <~ signal.optionalize()
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
/// // signal's `completed` event.
/// disposable.dispose()
/// ````
///
/// - note: The binding will automatically terminate when the property is 
///         deinitialized, or when the created producer sends a `completed` 
///         event.
///
/// - parameters:
///   - property: A property to bind to.
///   - producer: A producer to bind.
///
/// - returns: A disposable that can be used to terminate binding before the
///            deinitialization of property or producer's `completed` event.
@discardableResult
public func <~ <P: MutablePropertyProtocol, S: SignalProducerProtocol where P.Value == S.Value?, S.Error == NoError>(property: P, producer: S) -> Disposable {
	return property <~ producer.optionalize()
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
///            producer's `completed` event.
@discardableResult
public func <~ <Destination: MutablePropertyProtocol, Source: PropertyProtocol where Destination.Value == Source.Value?>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
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
///            producer's `completed` event.
@discardableResult
public func <~ <Destination: MutablePropertyProtocol, Source: PropertyProtocol where Source.Value == Destination.Value>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
}
