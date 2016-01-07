import Foundation

/// Represents a property that allows observation of its changes.
public protocol PropertyType {
	typealias Value

	/// The current value of the property.
	var value: Value { get }

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time.
	var producer: SignalProducer<Value, NoError> { get }

	/// A signal that will send the property's changes over time.
	var signal: Signal<Value, NoError> { get }
}

extension PropertyType {
	/// Maps each value in the property to a new value.
	@warn_unused_result
	public func map<U>(transform: Value -> U) -> AnyProperty<U> {
		return AnyProperty(
			initialValue: transform(value),
			signal: signal.map(transform)
		)
	}

	/// Combines the latest value of the receiver with the latest value from
	/// the given property.
	@warn_unused_result
	public func combineLatestWith<Other: PropertyType>(otherProperty: Other) -> AnyProperty<(Value, Other.Value)> {
		return AnyProperty(
			initialValue: (value, otherProperty.value),
			producer: producer.combineLatestWith(otherProperty.producer).skip(1)
		)
	}

	/// Zips elements of two properties into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input properties.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func zipWith<Other: PropertyType>(otherProperty: Other) -> AnyProperty<(Value, Other.Value)> {
		return AnyProperty(
			initialValue: (value, otherProperty.value),
			signal: signal.zipWith(otherProperty.signal)
		)
	}
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
	public init<P: PropertyType where P.Value == Value>(_ property: P) {
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
	private var _value: Value

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all observers of any Signals
	/// created from the `values` producer.
	public var value: Value {
		get {
			return withValue { $0 }
		}

		set {
			modify { _ in newValue }
		}
	}

	/// A signal that will send the property's changes over time,
	/// then complete when the property has deinitialized.
	public lazy var signal: Signal<Value, NoError> = { [unowned self] in
		var extractedSignal: Signal<Value, NoError>!
		self.producer.startWithSignal { signal, _ in
			extractedSignal = signal
		}
		return extractedSignal
	}()

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	public let producer: SignalProducer<Value, NoError>

	/// Initializes the property with the given value to start.
	public init(_ initialValue: Value) {
		_value = initialValue

		lock = NSRecursiveLock()
		lock.name = "org.reactivecocoa.ReactiveCocoa.MutableProperty"

		(producer, observer) = SignalProducer.buffer(1)
		observer.sendNext(initialValue)
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
		lock.lock()
		defer { lock.unlock() }

		let oldValue = _value
		_value = try action(_value)
		observer.sendNext(_value)
		return oldValue
	}

	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	public func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
		lock.lock()
		defer { lock.unlock() }

		return try action(_value)
	}

	deinit {
		observer.sendCompleted()
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

	private var property: MutableProperty<AnyObject?>?

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
		return property?.producer ?? .empty
	}

	public var signal: Signal<AnyObject?, NoError> {
		return property?.signal ?? .empty
	}

	/// Initializes a property that will observe and set the given key path of
	/// the given object. `object` must support weak references!
	public init(object: NSObject?, keyPath: String) {
		self.object = object
		self.keyPath = keyPath
		self.property = MutableProperty(nil)

		/// DynamicProperty stay alive as long as object is alive.
		/// This is made possible by strong reference cycles.
		super.init()

		object?.rac_valuesForKeyPath(keyPath, observer: nil)?
			.toSignalProducer()
			.start { event in
				switch event {
				case let .Next(newValue):
					self.property?.value = newValue
				case let .Failed(error):
					fatalError("Received unexpected error from KVO signal: \(error)")
				case .Interrupted, .Completed:
					self.property = nil
				}
			}
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
		default:
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

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType>(a: A, _ b: B) -> AnyProperty<(A.Value, B.Value)> {
	return a.combineLatestWith(b)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType>(a: A, _ b: B, _ c: C) -> AnyProperty<(A.Value, B.Value, C.Value)> {
	return combineLatest(a, b)
		.combineLatestWith(c)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType>(a: A, _ b: B, _ c: C, _ d: D) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value)> {
	return combineLatest(a, b, c)
		.combineLatestWith(d)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
	return combineLatest(a, b, c, d)
		.combineLatestWith(e)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
	return combineLatest(a, b, c, d, e)
		.combineLatestWith(f)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
	return combineLatest(a, b, c, d, e, f)
		.combineLatestWith(g)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
	return combineLatest(a, b, c, d, e, f, g)
		.combineLatestWith(h)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
	return combineLatest(a, b, c, d, e, f, g, h)
		.combineLatestWith(i)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`.
@warn_unused_result
public func combineLatest<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType, J: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
	return combineLatest(a, b, c, d, e, f, g, h, i)
		.combineLatestWith(j)
		.map(repack)
}

/// Combines the values of all the given properties, in the manner described by
/// `combineLatestWith`. Will return a property with a value of `[]` if the
/// sequence is empty.
@warn_unused_result
public func combineLatest<S: SequenceType, Value where S.Generator.Element == AnyProperty<Value>>(properties: S) -> AnyProperty<[Value]> {
	var generator = properties.generate()
	if let first = generator.next() {
		let initial = first.map { [$0] }
		return GeneratorSequence(generator).reduce(initial) { property, next in
			property.combineLatestWith(next).map { $0.0 + [$0.1] }
		}
	}

	return AnyProperty(initialValue: [], producer: SignalProducer.empty)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType>(a: A, _ b: B) -> AnyProperty<(A.Value, B.Value)> {
	return a.zipWith(b)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType, C: PropertyType>(a: A, _ b: B, _ c: C) -> AnyProperty<(A.Value, B.Value, C.Value)> {
	return zip(a, b)
		.zipWith(c)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType>(a: A, _ b: B, _ c: C, _ d: D) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value)> {
	return zip(a, b, c)
		.zipWith(d)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value)> {
	return zip(a, b, c, d)
		.zipWith(e)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value)> {
	return zip(a, b, c, d, e)
		.zipWith(f)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value)> {
	return zip(a, b, c, d, e, f)
		.zipWith(g)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value)> {
	return zip(a, b, c, d, e, f, g)
		.zipWith(h)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value)> {
	return zip(a, b, c, d, e, f, g, h)
		.zipWith(i)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`.
@warn_unused_result
public func zip<A: PropertyType, B: PropertyType, C: PropertyType, D: PropertyType, E: PropertyType, F: PropertyType, G: PropertyType, H: PropertyType, I: PropertyType, J: PropertyType>(a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> AnyProperty<(A.Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value)> {
	return zip(a, b, c, d, e, f, g, h, i)
		.zipWith(j)
		.map(repack)
}

/// Zips the values of all the given properties, in the manner described by
/// `zipWith`. Will return a property with a value of `[]` if the
/// sequence is empty.
@warn_unused_result
public func zip<S: SequenceType, Value where S.Generator.Element == AnyProperty<Value>>(properties: S) -> AnyProperty<[Value]> {
	var generator = properties.generate()
	if let first = generator.next() {
		let initial = first.map { [$0] }
		return GeneratorSequence(generator).reduce(initial) { property, next in
			property.zipWith(next).map { $0.0 + [$0.1] }
		}
	}

	return AnyProperty(initialValue: [], producer: SignalProducer.empty)
}
