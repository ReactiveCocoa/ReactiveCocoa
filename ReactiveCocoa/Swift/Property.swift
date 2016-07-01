import Foundation
import enum Result.NoError

/// Represents a property that allows observation of its changes.
public protocol PropertyProtocol {
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
public protocol MutablePropertyProtocol: class, PropertyProtocol {
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
extension PropertyProtocol {
	/// Lifts a unary SignalProducer operator to operate upon PropertyProtocol instead.
	private func lift<U>( _ transform: @noescape (SignalProducer<Value, NoError>) -> SignalProducer<U, NoError>) -> Property<U> {
		return Property(sourcingFrom: self, transform: transform)
	}

	/// Lifts a binary SignalProducer operator to operate upon PropertyProtocol instead.
	private func lift<P: PropertyProtocol, U>(_ transform: @noescape (SignalProducer<Value, NoError>) -> (SignalProducer<P.Value, NoError>) -> SignalProducer<U, NoError>) -> @noescape (P) -> Property<U> {
		return { otherProperty in
			return Property(sourcingFrom: (self, otherProperty), transform: transform)
		}
	}

	/// Maps the current value and all subsequent values to a new property.
	public func map<U>(_ transform: (Value) -> U) -> Property<U> {
		return lift { $0.map(transform) }
	}

	/// Combines the current value and the subsequent values of two `Property`s in
	/// the manner described by `Signal.combineLatestWith:`.
	public func combineLatest<P: PropertyProtocol>(with other: P) -> Property<(Value, P.Value)> {
		return lift(SignalProducer.combineLatest(with:))(other)
	}

	/// Zips the current value and the subsequent values of two `Property`s in
	/// the manner described by `Signal.zipWith`.
	public func zip<P: PropertyProtocol>(with other: P) -> Property<(Value, P.Value)> {
		return lift(SignalProducer.zip(with:))(other)
	}

	/// Forwards events from `self` with history: values of the returned property
	/// are a tuple whose first member is the previous value and whose second member
	/// is the current value. `initial` is supplied as the first member of the first
	/// tuple.
	public func combinePrevious(initial: Value) -> Property<(Value, Value)> {
		return lift { $0.combinePrevious(initial: initial) }
	}

	/// Forwards only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value. The first value is always forwarded.
	public func skipRepeats(_ isRepeat: (Value, Value) -> Bool) -> Property<Value> {
		return lift { $0.skipRepeats(isRepeat) }
	}
}

extension PropertyProtocol where Value: Equatable {
	/// Forwards only those values from `self` which is not equal to the previous
	/// value. The first value is always forwarded.
	public func skipRepeats() -> Property<Value> {
		return lift { $0.skipRepeats() }
	}
}

extension PropertyProtocol where Value: PropertyProtocol {
	/// Flattens the inner properties sent upon `self` (into a single property),
	/// according to the semantics of the given strategy.
	public func flatten(_ strategy: FlattenStrategy) -> Property<Value.Value> {
		return lift { $0.flatMap(strategy) { $0.producer } }
	}
}

extension PropertyProtocol {
	/// Maps each property from `self` to a new property, then flattens the
	/// resulting properties (into a single property), according to the
	/// semantics of the given strategy.
	public func flatMap<P: PropertyProtocol>(_ strategy: FlattenStrategy, transform: (Value) -> P) -> Property<P.Value> {
		return lift { $0.flatMap(strategy) { transform($0).producer } }
	}

	/// Forwards only those values from `self` that have unique identities across the set of
	/// all values that have been seen.
	///
	/// Note: This causes the identities to be retained to check for uniqueness.
	public func uniqueValues<Identity: Hashable>(_ transform: (Value) -> Identity) -> Property<Value> {
		return lift { $0.uniqueValues(transform) }
	}
}

extension PropertyProtocol where Value: Hashable {
	/// Forwards only those values from `self` that are unique across the set of
	/// all values that have been seen.
	///
	/// Note: This causes the values to be retained to check for uniqueness. Providing
	/// a function that returns a unique value for each sent value can help you reduce
	/// the memory footprint.
	public func uniqueValues() -> Property<Value> {
		return lift { $0.uniqueValues() }
	}
}

extension PropertyProtocol {
	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B) -> Property<(A.Value, B.Value)> {
		return a.combineLatest(with: b)
	}

	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C) -> Property<(A.Value, B.Value, C.Value)> {
		return combineLatest(a, b)
			.combineLatest(with: c)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D) -> Property<(A.Value, B.Value, C.Value, D.Value)> {
		return combineLatest(a, b, c)
			.combineLatest(with: d)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
		return combineLatest(a, b, c, d)
			.combineLatest(with: e)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
		return combineLatest(a, b, c, d, e)
			.combineLatest(with: f)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
		return combineLatest(a, b, c, d, e, f)
			.combineLatest(with: g)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
		return combineLatest(a, b, c, d, e, f, g)
			.combineLatest(with: h)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
		return combineLatest(a, b, c, d, e, f, g, h)
			.combineLatest(with: i)
			.map(repack)
	}

	/// Combines the values of all the given properties, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol, J: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
		return combineLatest(a, b, c, d, e, f, g, h, i)
			.combineLatest(with: j)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`. Returns nil if the sequence is empty.
	public static func combineLatest<S: Sequence where S.Iterator.Element: PropertyProtocol>(_ properties: S) -> Property<[S.Iterator.Element.Value]>? {
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
	public static func zip<A: PropertyProtocol, B: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B) -> Property<(A.Value, B.Value)> {
		return a.zip(with: b)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C) -> Property<(A.Value, B.Value, C.Value)> {
		return zip(a, b)
			.zip(with: c)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D) -> Property<(A.Value, B.Value, C.Value, D.Value)> {
		return zip(a, b, c)
			.zip(with: d)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
		return zip(a, b, c, d)
			.zip(with: e)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
		return zip(a, b, c, d, e)
			.zip(with: f)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
		return zip(a, b, c, d, e, f)
			.zip(with: g)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
		return zip(a, b, c, d, e, f, g)
			.zip(with: h)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
		return zip(a, b, c, d, e, f, g, h)
			.zip(with: i)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: PropertyProtocol, B: PropertyProtocol, C: PropertyProtocol, D: PropertyProtocol, E: PropertyProtocol, F: PropertyProtocol, G: PropertyProtocol, H: PropertyProtocol, I: PropertyProtocol, J: PropertyProtocol where Value == A.Value>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> Property<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
		return zip(a, b, c, d, e, f, g, h, i)
			.zip(with: j)
			.map(repack)
	}

	/// Zips the values of all the given properties, in the manner described by
	/// `zip(with:)`. Returns nil if the sequence is empty.
	public static func zip<S: Sequence where S.Iterator.Element: PropertyProtocol>(_ properties: S) -> Property<[S.Iterator.Element.Value]>? {
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
public struct Property<Value>: PropertyProtocol {
	private let sources: [Any]
	private let disposable: Disposable?

	private let _value: () -> Value
	private let _producer: () -> SignalProducer<Value, NoError>
	private let _signal: () -> Signal<Value, NoError>

	/// The current value of the property.
	public var value: Value {
		return _value()
	}

	/// A producer that sends the property's current value, followed by all changes
	/// over time.
	public var producer: SignalProducer<Value, NoError> {
		return _producer()
	}

	/// A signal that sends the property's changes over time.
	///
	/// - Warning: It is strongly discouraged to use `signal` on any composed properties.
	public var signal: Signal<Value, NoError> {
		return _signal()
	}

	/// Initializes an existential property.
	public init<P: PropertyProtocol where P.Value == Value>(_ property: P) {
		sources = Property.capturing(property)
		disposable = nil
		_value = { property.value }
		_producer = { property.producer }
		_signal = { property.signal }
	}

	/// Initializes a constant property.
	/// Its producer and signal would complete immediately at initialization.
	public init(value: Value) {
		sources = []
		disposable = nil
		_value = { value }
		_producer = { SignalProducer(value: value) }
		_signal = { Signal.empty }
	}

	/// Initializes a composed property that first takes on `initial`, then each value
	/// sent on a signal created by `producer`.
	public init(initial: Value, followingBy producer: SignalProducer<Value, NoError>) {
		self.init(sourcingFrom: producer.prefix(value: initial),
		          capturing: [])
	}

	/// Initializes a composed property that first takes on `initial`, then each value
	/// sent on `signal`.
	public init(initial: Value, followingBy signal: Signal<Value, NoError>) {
		self.init(sourcingFrom: SignalProducer(signal: signal).prefix(value: initial),
		          capturing: [])
	}

	/// Initializes a composed property by applying the unary `SignalProducer` transform on
	/// `property`. The resulting property captures `property`.
	private init<P: PropertyProtocol>(sourcingFrom property: P, transform: @noescape (SignalProducer<P.Value, NoError>) -> SignalProducer<Value, NoError>) {
		self.init(sourcingFrom: transform(property.producer),
		          capturing: Property.capturing(property))
	}

	/// Initializes a composed property by applying the binary `SignalProducer` transform on
	/// `properties.first` and `properties.second`. The resulting property captures
	/// the two property sources.
	private init<P1: PropertyProtocol, P2: PropertyProtocol>(sourcingFrom properties: (first: P1, second: P2), transform: @noescape (SignalProducer<P1.Value, NoError>) -> (SignalProducer<P2.Value, NoError>) -> SignalProducer<Value, NoError>) {
		self.init(sourcingFrom: transform(properties.first.producer)(properties.second.producer),
		          capturing: Property.capturing(properties.first) + Property.capturing(properties.second))
	}

	/// Initializes a composed property from a producer that promises to send at least one
	/// value synchronously in its start handler before sending any subsequent event.
	/// If the producer fails its promise, a fatal error would be raised.
	///
	/// The producer and the signal of the created property would complete only
	/// when the `unsafeProducer` completes.
	private init(sourcingFrom unsafeProducer: SignalProducer<Value, NoError>, capturing sources: [Any]) {
		var value: Value!

		let observerDisposable = unsafeProducer.start { event in
			switch event {
			case let .next(newValue):
				value = newValue

			case .completed, .interrupted:
				break

			case let .failed(error):
				fatalError("Receive unexpected error from a producer of `NoError` type: \(error)")
			}
		}

		if value != nil {
			disposable = ScopedDisposable(observerDisposable)
			self.sources = sources

			_value = { value }
			_producer = { unsafeProducer }
			_signal = {
				var extractedSignal: Signal<Value, NoError>!
				unsafeProducer.startWithSignal { signal, _ in extractedSignal = signal }
				return extractedSignal
			}
		} else {
			fatalError("A producer promised to send at least one value. Received none.")
		}
	}

	/// Check if `property` is an `AnyProperty` and has already captured its sources
	/// using a closure. Returns that closure if it does. Otherwise, returns a closure
	/// which captures `property`.
	private static func capturing<P: PropertyProtocol>(_ property: P) -> [Any] {
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

	/// Need a recursive lock around `value` to allow recursive access to
	/// `value`. Note that recursive sets will still deadlock because the
	/// underlying producer prevents sending recursive events.
	private let lock: RecursiveLock

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

	/// Initializes the property with the given value to start.
	public init(_ initialValue: Value) {
		lock = RecursiveLock()
		lock.name = "org.reactivecocoa.ReactiveCocoa.MutableProperty"

		box = Box(initialValue)
		(signal, observer) = Signal.pipe()
	}

	/// Atomically replaces the contents of the variable.
	///
	/// Returns the old value.
	@discardableResult
	public func swap(_ newValue: Value) -> Value {
		return modify { $0 = newValue }
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
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
	/// Returns the result of the action.
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
/// The binding will automatically terminate when the property is deinitialized,
/// or when the signal sends a `Completed` event.
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
/// The binding will automatically terminate when the property is deinitialized,
/// or when the created signal sends a `Completed` event.
@discardableResult
public func <~ <P: MutablePropertyProtocol>(property: P, producer: SignalProducer<P.Value, NoError>) -> Disposable {
	let disposable = CompositeDisposable()

	producer.startWithSignal { signal, signalDisposable in
		property <~ signal
		disposable += signalDisposable

		disposable += property.producer.startWithCompleted {
			disposable.dispose()
		}
	}

	return disposable
}

@discardableResult
public func <~ <P: MutablePropertyProtocol, S: SignalProtocol where P.Value == S.Value?, S.Error == NoError>(property: P, signal: S) -> Disposable {
	return property <~ signal.optionalize()
}

@discardableResult
public func <~ <P: MutablePropertyProtocol, S: SignalProducerProtocol where P.Value == S.Value?, S.Error == NoError>(property: P, producer: S) -> Disposable {
	return property <~ producer.optionalize()
}

@discardableResult
public func <~ <Destination: MutablePropertyProtocol, Source: PropertyProtocol where Destination.Value == Source.Value?>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
}

/// Binds `destinationProperty` to the latest values of `sourceProperty`.
///
/// The binding will automatically terminate when either property is
/// deinitialized.
@discardableResult
public func <~ <Destination: MutablePropertyProtocol, Source: PropertyProtocol where Source.Value == Destination.Value>(destinationProperty: Destination, sourceProperty: Source) -> Disposable {
	return destinationProperty <~ sourceProperty.producer
}
