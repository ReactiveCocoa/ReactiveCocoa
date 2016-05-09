import enum Result.NoError

public protocol MethodType: class {
	associatedtype Object: AnyObject
	associatedtype Input
	associatedtype Output

	weak var object: Object? { get }
	var function: (Object, Input) -> Output { get }
}

public extension MethodType {
	func call(input: Input) -> Output? {
		return object.map { function($0, input) }
	}

	func lift<Error: ErrorType>(with signal: Signal<Input, Error>) -> Signal<Output, Error> {
		if object == nil {
			return Signal { observer in
				observer.sendInterrupted()
				return nil
			}
		}

		return signal
			.map(call)
			.materialize()
			.map { event -> Event<Output?, Error> in
				if case .Next(.None) = event {
					return .Interrupted
				} else {
					return event
				}
			}
			.dematerialize()
			.ignoreNil()
	}

	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	func lifted<Error: ErrorType>(with producer: SignalProducer<Input, Error>) -> SignalProducer<Output, Error> {
		return _lifted(method: self, with: producer, lift: self.lift)
	}
}

/// Implementation detail of overloads for `MethodType.lifted(with:)`.
@_transparent private func _lifted<Method: MethodType, Error: ErrorType>(method method: Method, with producer: SignalProducer<Method.Input, Error>, lift: Signal<Method.Input, Error> -> Signal<Method.Output, Error>) -> SignalProducer<Method.Output, Error> {
	return SignalProducer { [weak method] observer, disposable in
		guard method != nil else {
			observer.sendInterrupted()
			return
		}

		producer.startWithSignal { signal, signalDisposable in
			disposable += signalDisposable
			disposable += lift(signal).observe(observer)
		}
	}
}

public final class Method<Object: AnyObject, Input, Output>: MethodType {
	public private(set) weak var object: Object?
	public let function: (Object, Input) -> Output

	public init(object: Object?, function: (Object, Input) -> Output) {
		self.object = object
		self.function = function
	}

	public init(object: Object?, function: Object -> Input -> Output) {
		self.object = object
		self.function = { object, input in function(object)(input) }
	}
}

#if _runtime(_ObjC)
public extension MethodType where Object: NSObject {
	func lift<Error: ErrorType>(with signal: Signal<Input, Error>) -> Signal<Output, Error> {
		guard let object: NSObject = object else { return .empty }

		let (deallocated, deallocatedObserver) = Signal<(), NoError>.pipe()
		object.rac_deallocDisposable.addDisposable(RACDisposable(block: deallocatedObserver.sendCompleted))

		return signal
			.takeUntil(deallocated)
			.materialize()
			.map { event -> Event<Input, Error> in
				if case .Completed = event {
					return .Interrupted
				} else {
					return event
				}
			}
			.dematerialize()
			.map(call)
			.ignoreNil()
	}

	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	func lifted<Error: ErrorType>(with producer: SignalProducer<Input, Error>) -> SignalProducer<Output, Error> {
		return _lifted(method: self, with: producer, lift: self.lift)
	}
}
#endif
