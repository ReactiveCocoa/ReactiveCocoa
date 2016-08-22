import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
///
/// Only classes can conform to this protocol, because having a signal
/// for changes over time implies the origin must have a unique identity.
public protocol PropertyProtocol: class {
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
public protocol MutablePropertyProtocol: PropertyProtocol {
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
	fileprivate func lift<U>(_ transform: @escaping (SignalProducer<Value, NoError>) -> SignalProducer<U, NoError>) -> Property<U> {
		return Property(self, transform: transform)
	}

	/// Lifts a binary SignalProducer operator to operate upon PropertyProtocol instead.
	fileprivate func lift<P: PropertyProtocol, U>(_ transform: @escaping (SignalProducer<Value, NoError>) -> (SignalProducer<P.Value, NoError>) -> SignalProducer<U, NoError>) -> (P) -> Property<U> {
		return { otherProperty in
			return Property(self, otherProperty, transform: transform)
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
	public func map<U>(_ transform: @escaping (Value) -> U) -> Property<U> {
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
	public func combineLatest<P: PropertyProtocol>(with other: P) -> Property<(Value, P.Value)> {
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
	public func zip<P: PropertyProtocol>(with other: P) -> Property<(Value, P.Value)> {
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
	public func combinePrevious(_ initial: Value) -> Property<(Value, Value)> {
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
	public func skipRepeats(_ isRepeat: @escaping (Value, Value) -> Bool) -> Property<Value> {
		return lift { $0.skipRepeats(isRepeat) }
	}
}

extension PropertyProtocol where Value: Equatable {
	/// Forward only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value.
	///
	/// - returns: A property that does not emit events for two equal values
	///            sequentially.
	public func skipRepeats() -> Property<Value> {
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
	public func flatten(_ strategy: FlattenStrategy) -> Property<Value.Value> {
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
	public func flatMap<P: PropertyProtocol>(_ strategy: FlattenStrategy, transform: @escaping (Value) -> P) -> Property<P.Value> {
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
	public func uniqueValues<Identity: Hashable>(_ transform: @escaping (Value) -> Identity) -> Property<Value> {
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
	public func uniqueValues() -> Property<Value> {
		return lift { $0.uniqueValues() }
	}
}

extension PropertyProtocol {
	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol>(_ a: A, _ b: B) -> Property<(A.Value, B.Value)> where Value == A.Value {
		return a.combineLatest(with: b)
	}

	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol>(_ a: A, _ b: B, _ c: C) -> Property<(A.Value, B.Value, C.Value)> where Value == A.Value {
		return combineLatest(a, b)
			.combineLatest(with: c)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D) -> Property<(A.Value, B.Value, C.Value, D.Value)> where Value == A.Value {
		return combineLatest(a, b, c)
			.combineLatest(with: d)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value)> where Value == A.Value {
		return combineLatest(a, b, c, d)
			.combineLatest(with: e)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> where Value == A.Value {
		return combineLatest(a, b, c, d, e)
			.combineLatest(with: f)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> where Value == A.Value {
		return combineLatest(a, b, c, d, e, f)
			.combineLatest(with: g)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> where Value == A.Value {
		return combineLatest(a, b, c, d, e, f, g)
			.combineLatest(with: h)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> where Value == A.Value {
		return combineLatest(a, b, c, d, e, f, g, h)
			.combineLatest(with: i)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described
	/// by `combineLatest(with:)`.
		public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol, J: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> where Value == A.Value {
		return combineLatest(a, b, c, d, e, f, g, h, i)
			.combineLatest(with: j)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`. Returns nil if the sequence is empty.
	public static func combineLatest<S: Sequence>(_ properties: S) -> Property<[S.Iterator.Element.Value]>? where S.Iterator.Element: PropertyProtocol {
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
	public static func zip<A: PropertyProtocol, B: PropertyProtocol>(_ a: A, _ b: B) -> Property<(A.Value, B.Value)> where Value == A.Value {
		return a.zip(with: b)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol>(_ a: A, _ b: B, _ c: C) -> Property<(A.Value, B.Value, C.Value)> where Value == A.Value {
		return zip(a, b)
			.zip(with: c)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D) -> Property<(A.Value, B.Value, C.Value, D.Value)> where Value == A.Value {
		return zip(a, b, c)
			.zip(with: d)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value)> where Value == A.Value {
		return zip(a, b, c, d)
			.zip(with: e)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> where Value == A.Value {
		return zip(a, b, c, d, e)
			.zip(with: f)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> where Value == A.Value {
		return zip(a, b, c, d, e, f)
			.zip(with: g)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> where Value == A.Value {
		return zip(a, b, c, d, e, f, g)
			.zip(with: h)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> where Value == A.Value {
		return zip(a, b, c, d, e, f, g, h)
			.zip(with: i)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol, J: PropertyProtocol>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> where Value == A.Value {
		return zip(a, b, c, d, e, f, g, h, i)
			.zip(with: j)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`. Returns nil if the sequence is empty.
	public static func zip<S: Sequence>(_ properties: S) -> Property<[S.Iterator.Element.Value]>? where S.Iterator.Element: PropertyProtocol {
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

/// A read-only property that can be observed for its changes over time. There are
/// three categories of read-only property:
///
/// # Constant property
/// Created by `Property(value:)`, the producer and signal of a constant
/// property would complete immediately when it is initialized.
///
/// # Existential property
/// Created by `Property(_:)`, an existential property passes through the
/// behavior of the wrapped property.
///
/// # Composed property
/// Created by either the compositional operators in `PropertyProtocol`, or
/// `Property(initial:followingBy:)`, a composed property presents a
/// composed view of its source, which can be a set of properties,
/// a producer, or a signal.
///
/// A composed property respects the lifetime of its source rather than its own.
/// In other words, its producer and signal can outlive the property itself, if
/// its source outlives it too.
public final class Property<Value>: PropertyProtocol {
	private let sources: [AnyObject]

	private let _value: () -> Value
	private let _producer: () -> SignalProducer<Value, NoError>
	private let _signal: () -> Signal<Value, NoError>

	/// The current value of the property.
	public var value: Value {
		return _value()
	}

	/// A producer for Signals that will send the property's current
	/// value, followed by all changes over time, then complete when the
	/// property has deinitialized or has no further changes.
	public var producer: SignalProducer<Value, NoError> {
		return _producer()
	}

	/// A signal that will send the property's changes over time, then
	/// complete when the property has deinitialized or has no further changes.
	public var signal: Signal<Value, NoError> {
		return _signal()
	}

	/// Initializes a constant property.
	///
	/// - parameters:
	///   - property: A value of the constant property.
	public init(value: Value) {
		sources = []
		_value = { value }
		_producer = { SignalProducer(value: value) }
		_signal = { Signal<Value, NoError>.empty }
	}

	/// Initializes an existential property which wraps the given property.
	///
	/// - parameters:
	///   - property: A property to be wrapped.
	public init<P: PropertyProtocol>(_ property: P) where P.Value == Value {
		sources = Property.capture(property)
		_value = { property.value }
		_producer = { property.producer }
		_signal = { property.signal }
	}

	/// Initializes a composed property that first takes on `initial`, then each
	/// value sent on a signal created by `producer`.
	///
	/// - parameters:
	///   - initial: Starting value for the property.
	///   - producer: A producer that will start immediately and send values to
	///               the property.
	public convenience init(initial: Value, then producer: SignalProducer<Value, NoError>) {
		self.init(unsafeProducer: producer.prefix(value: initial),
		          capturing: [])
	}

	/// Initialize a composed property that first takes on `initial`, then each
	/// value sent on `signal`.
	///
	/// - parameters:
	///   - initialValue: Starting value for the property.
	///   - signal: A signal that will send values to the property.
	public convenience init(initial: Value, then signal: Signal<Value, NoError>) {
		self.init(unsafeProducer: SignalProducer(signal: signal).prefix(value: initial),
		          capturing: [])
	}

	/// Initialize a composed property by applying the unary `SignalProducer`
	/// transform on `property`.
	///
	/// - parameters:
	///   - property: The source property.
	///   - transform: A unary `SignalProducer` transform to be applied on
	///     `property`.
	fileprivate convenience init<P: PropertyProtocol>(
		_ property: P,
		transform: @escaping (SignalProducer<P.Value, NoError>) -> SignalProducer<Value, NoError>
	) {
		self.init(
			unsafeProducer: transform(property.producer),
			capturing: Property.capture(property)
		)
	}

	/// Initialize a composed property by applying the binary `SignalProducer`
	/// transform on `firstProperty` and `secondProperty`.
	///
	/// - parameters:
	///   - firstProperty: The first source property.
	///   - secondProperty: The first source property.
	///   - transform: A binary `SignalProducer` transform to be applied on
	///             `firstProperty` and `secondProperty`.
	fileprivate convenience init<P1: PropertyProtocol, P2: PropertyProtocol>(_ firstProperty: P1, _ secondProperty: P2, transform: @escaping (SignalProducer<P1.Value, NoError>) -> (SignalProducer<P2.Value, NoError>) -> SignalProducer<Value, NoError>) {
		self.init(unsafeProducer: transform(firstProperty.producer)(secondProperty.producer),
		          capturing: Property.capture(firstProperty) + Property.capture(secondProperty))
	}

	/// Initialize a composed property from a producer that promises to send
	/// at least one value synchronously in its start handler before sending any
	/// subsequent event.
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
	private init(unsafeProducer: SignalProducer<Value, NoError>, capturing sources: [AnyObject]) {
		// Share a replayed producer with `self.producer` and `self.signal` so
		// they see a consistent view of the `self.value`.
		// https://github.com/ReactiveCocoa/ReactiveCocoa/pull/3042
		let producer = unsafeProducer.replayLazily(upTo: 1)
		
		// Verify that an initial is sent. This is friendlier than deadlocking
		// in the event that one isn't.
		var value: Value? = nil
		let disposable = producer.start { event in
			switch event {
			case let .next(newValue):
				value = newValue
				
			case .completed, .interrupted:
				break
				
			case let .failed(error):
				fatalError("Receive unexpected error from a producer of `NoError` type: \(error)")
			}
		}
		guard value != nil else {
			fatalError("A producer promised to send at least one value. Received none.")
		}
		disposable.dispose()

		self.sources = sources
		_value = { producer.take(first: 1).single()!.value! }
		_producer = { producer }
		_signal = {
			var extractedSignal: Signal<Value, NoError>!
			producer.startWithSignal { signal, _ in extractedSignal = signal }
			return extractedSignal
		}
	}

	/// Inspect if `property` is an `AnyProperty` and has already captured its
	/// sources using a closure. Returns that closure if it does. Otherwise,
	/// returns a closure which captures `property`.
	///
	/// - parameters:
	///   - property: The property to be insepcted.
	private static func capture<P: PropertyProtocol>(_ property: P) -> [AnyObject] {
		if let property = property as? Property<P.Value> {
			return property.sources
		} else {
			return [property]
		}
	}
}

/// A mutable property of type `Value` that allows observation of its changes.
///
/// Instances of this class are thread-safe.
public final class MutableProperty<Value>: MutablePropertyProtocol {
	private let observer: Signal<Value, NoError>.Observer

	private let atomic: RecursiveAtomic<Value>

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all observers of `signal`, or
	/// signals created using `producer`.
	public var value: Value {
		get {
			return atomic.withValue { $0 }
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
		return SignalProducer { [atomic, weak self] producerObserver, producerDisposable in
			atomic.withValue { value in
				if let strongSelf = self {
					producerObserver.sendNext(value)
					producerDisposable += strongSelf.signal.observe(producerObserver)
				} else {
					producerObserver.sendNext(value)
					producerObserver.sendCompleted()
				}
			}
		}
	}

	/// Initializes a mutable property that first takes on `initialValue`
	///
	/// - parameters:
	///   - initialValue: Starting value for the mutable property.
	public init(_ initialValue: Value) {
		(signal, observer) = Signal.pipe()

		/// Need a recursive lock around `value` to allow recursive access to
		/// `value`. Note that recursive sets will still deadlock because the
		/// underlying producer prevents sending recursive events.
		atomic = RecursiveAtomic(initialValue,
		                          name: "org.reactivecocoa.ReactiveCocoa.MutableProperty",
		                          didSet: observer.sendNext)
	}

	/// Atomically replaces the contents of the variable.
	///
	/// - parameters:
	///   - newValue: New property value.
	///
	/// - returns: The previous property value.
	@discardableResult
	public func swap(_ newValue: Value) -> Value {
		return atomic.swap(newValue)
	}

	/// Atomically modifies the variable.
	///
	/// - parameters:
	///   - action: A closure that accepts old property value and returns a new
	///             property value.
	///
	/// - returns: The result of the action.
	@discardableResult
	public func modify<Result>(_ action: (inout Value) throws -> Result) rethrows -> Result {
		return try atomic.modify(action)
	}

	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// - parameters:
	///   - action: A closure that accepts current property value.
	///
	/// - returns: the result of the action.
	@discardableResult
	public func withValue<Result>(action: (Value) throws -> Result) rethrows -> Result {
		return try atomic.withValue(action)
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
public func <~ <P: MutablePropertyProtocol, S: SignalProtocol>(property: P, signal: S) -> Disposable where P.Value == S.Value?, S.Error == NoError {
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
public func <~ <P: MutablePropertyProtocol, S: SignalProducerProtocol>(property: P, producer: S) -> Disposable where P.Value == S.Value?, S.Error == NoError {
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
public func <~ <Destination: MutablePropertyProtocol, Source: PropertyProtocol>(destinationProperty: Destination, sourceProperty: Source) -> Disposable where Destination.Value == Source.Value? {
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
public func <~ <Destination: MutablePropertyProtocol, Source: PropertyProtocol>(destinationProperty: Destination, sourceProperty: Source) -> Disposable where Source.Value == Destination.Value {
	return destinationProperty <~ sourceProperty.producer
}
