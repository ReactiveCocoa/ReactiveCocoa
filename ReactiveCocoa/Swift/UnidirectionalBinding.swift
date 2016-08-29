import enum Result.NoError

precedencegroup BindingPrecedence {
	associativity: right

	// Binds tighter than assignment but looser than everything else
	higherThan: AssignmentPrecedence
}

infix operator <~ : BindingPrecedence

/// Describes a target to which can be bound.
public protocol BindingTarget: class {
	associatedtype Value

	/// The lifetime of `self`. The binding operators use this to determine when
	/// the binding should be teared down.
	var lifetime: Lifetime { get }

	/// Consume a value from the binding.
	func consume(_ value: Value)

	/// Binds a signal to a target, updating the target's value to the latest
	/// value sent by the signal.
	///
	/// - note: The binding will automatically terminate when the target is
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
	///   - target: A target to be bond to.
	///   - signal: A signal to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the signal's `completed`
	///            event.
	@discardableResult
	static func <~ <Source: SignalProtocol>(target: Self, signal: Source) -> Disposable? where Source.Value == Value, Source.Error == NoError
}

extension BindingTarget {
	/// Binds a signal to a target, updating the target's value to the latest
	/// value sent by the signal.
	///
	/// - note: The binding will automatically terminate when the target is
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
	///   - target: A target to be bond to.
	///   - signal: A signal to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the signal's `completed`
	///            event.
	@discardableResult
	public static func <~ <Source: SignalProtocol>(target: Self, signal: Source) -> Disposable? where Source.Value == Value, Source.Error == NoError {
		return signal
			.take(during: target.lifetime)
			.observeNext { [weak target] value in
				target?.consume(value)
			}
	}

	/// Binds a producer to a target, updating the target's value to the latest
	/// value sent by the producer.
	///
	/// - note: The binding will automatically terminate when the target is
	///         deinitialized, or when the producer sends a `completed` event.
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
	/// - parameters:
	///   - target: A target to be bond to.
	///   - producer: A producer to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the producer's `completed
	///            event.
	@discardableResult
	public static func <~ <Source: SignalProducerProtocol>(target: Self, producer: Source) -> Disposable where Source.Value == Value, Source.Error == NoError {
		var disposable: Disposable!

		producer
			.take(during: target.lifetime)
			.startWithSignal { signal, signalDisposable in
				disposable = signalDisposable
				target <~ signal
			}

		return disposable
	}

	/// Binds a property to a target, updating the target's value to the latest
	/// value sent by the property.
	///
	/// - note: The binding will automatically terminate when either the target or
	///         the property deinitializes.
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
	/// - parameters:
	///   - target: A target to be bond to.
	///   - property: A property to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the source property.
	@discardableResult
	public static func <~ <Source: PropertyProtocol>(target: Self, property: Source) -> Disposable where Source.Value == Value {
		return target <~ property.producer
	}
}

extension BindingTarget where Value: OptionalProtocol {
	/// Binds a signal to a target, updating the target's value to the latest
	/// value sent by the signal.
	///
	/// - note: The binding will automatically terminate when the target is
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
	///   - target: A target to be bond to.
	///   - signal: A signal to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the signal's `completed`
	///            event.
	@discardableResult
	public static func <~ <Source: SignalProtocol>(target: Self, signal: Source) -> Disposable? where Source.Value == Value.Wrapped, Source.Error == NoError {
		return target <~ signal.map(Value.init(reconstructing:))
	}

	/// Binds a producer to a target, updating the target's value to the latest
	/// value sent by the producer.
	///
	/// - note: The binding will automatically terminate when the target is
	///         deinitialized, or when the producer sends a `completed` event.
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
	/// - parameters:
	///   - target: A target to be bond to.
	///   - producer: A producer to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the producer's `completed`
	///            event.
	@discardableResult
	public static func <~ <Source: SignalProducerProtocol>(target: Self, producer: Source) -> Disposable where Source.Value == Value.Wrapped, Source.Error == NoError {
		return target <~ producer.map(Value.init(reconstructing:))
	}

	/// Binds a property to a target, updating the target's value to the latest
	/// value sent by the property.
	///
	/// - note: The binding will automatically terminate when either the target or
	///         the property deinitializes.
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
	///   - target: A target to be bond to.
	///   - property: A property to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the source property.
	@discardableResult
	public static func <~ <Source: PropertyProtocol>(target: Self, property: Source) -> Disposable where Source.Value == Value.Wrapped {
		return target <~ property.producer
	}
}
