import ReactiveCocoa
import ReactiveSwift
import Result

internal enum TestError: Int {
	case `default` = 0
	case error1 = 1
	case error2 = 2
}

extension TestError: Error {
}


internal extension SignalProducer {
	/// Halts if an error is emitted in the receiver signal.
	/// This is useful in tests to be able to just use `startWithNext`
	/// in cases where we know that an error won't be emitted.
	func assumeNevers() -> SignalProducer<Value, Never> {
		return lift { $0.assumeNevers() }
	}
}

internal extension Signal {
	/// Halts if an error is emitted in the receiver signal.
	/// This is useful in tests to be able to just use `startWithNext`
	/// in cases where we know that an error won't be emitted.
	func assumeNevers() -> Signal<Value, Never> {
		return mapError { error in
			fatalError("Unexpected error: \(error)")

			()
		}
	}
}

