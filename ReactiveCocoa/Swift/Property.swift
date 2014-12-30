/// A mutable property of type T that allows observation of its changes.
///
/// Instances of this class are thread-safe.
public final class Property<T> {
	/// The current value of the property.
	///
	/// Setting this to a new value will notify all observers of any Signals
	/// created from the `values` producer.
	public var value: T { get set }

	/// A producer for a signal that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	public let valuesProducer: SignalProducer<T>

	/// Initializes a property with the given value to start.
	public init(_ initialValue: T)
}

infix operator <~ {
	associativity right
	precedence 90
}

/// Binds a signal to a property, updating the property's value to the latest
/// value sent by the signal.
///
/// The signal MUST NOT send an error. The behavior of doing so is undefined.
///
/// The binding will automatically terminate when the property is deinitialized,
/// or when the signal sends a `Completed` event.
public func <~ <T>(property: Property<T>, signal: Signal<T>)

/// Creates a signal from the given producer, which will be immediately bound to
/// the given property, updating the property's value to the latest value sent
/// by the signal.
///
/// The created signal MUST NOT send an error. The behavior of doing so is
/// undefined.
///
/// The binding will automatically terminate when the property is deinitialized,
/// or when the created signal sends a `Completed` event.
public func <~ <T>(property: Property<T>, producer: SignalProducer<T>)
