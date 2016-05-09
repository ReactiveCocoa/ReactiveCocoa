import enum Result.NoError

infix operator <~ {
	associativity right

	// Binds tighter than assignment but looser than everything else
	precedence 93
}

public protocol Bindable {
	associatedtype Input

	/// An optional signal that should trigger a binding to be terminated
	/// by sending a `Completed` event.
	///
	/// For example, this could represent the underlying object of a bound
	/// property being deallocated.
	var complete: Signal<(), NoError>? { get }

	/// For every value sent on `signal`, update the destination value.
	///
	/// A binding may automatically terminate when the `complete` signal terminates.
	/// A binding must automatically terminate the signal sends a `Completed` event.
	func <~ (bindable: Self, signal: Signal<Input, NoError>) -> Disposable

	/// Creates a signal from the given producer, which will be immediately bound to
	/// the destination, updating its value to the latest value sent by the signal.
	///
	/// A binding may automatically terminate when the `complete` signal terminates.
	/// A binding must automatically terminate the signal sends a `Completed` event.
	func <~ (bindable: Self, signal: SignalProducer<Input, NoError>) -> Disposable
}

/// Creates a signal from the given producer, which will be immediately bound to
/// the destination, updating its value to the latest value sent by the signal.
///
/// The binding will automatically terminate if the `complete` signal sends a `Completed` event,
/// or when the created signal sends a `Completed` event.
public func <~ <B: Bindable>(bindable: B, producer: SignalProducer<B.Input, NoError>) -> Disposable {
	var disposable: Disposable!

	producer.startWithSignal { signal, signalDisposable in
		disposable = signalDisposable
		bindable <~ signal

		bindable.complete?.observeCompleted {
			signalDisposable.dispose()
		}
	}

	return disposable
}

/// Binds `bindable` to the latest values of `sourceProperty`.
///
/// The binding will automatically terminate when its `complete` signal
/// sends a `Completed` event, or when `sourceProperty` terminates.
public func <~ <B: Bindable, P: PropertyType where P.Value == B.Input>(bindable: B, sourceProperty: P) -> Disposable {
	return bindable <~ sourceProperty.producer
}
