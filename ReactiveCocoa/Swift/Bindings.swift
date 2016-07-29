import Foundation
import enum Result.NoError

/// Represents a target to which can be bond.
///
/// Only classes can conform to this protocol, because instances must support
/// weak references (and value types currently do not).
public protocol BindingTarget: class {
	associatedtype Value

	/// Set the value of the property.
	///
	/// - parameter:
	///   - value: The desired new value of the property.
	func set(_ value: Value)
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
