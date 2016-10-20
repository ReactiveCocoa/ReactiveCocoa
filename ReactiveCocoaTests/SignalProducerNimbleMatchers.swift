import Foundation
import ReactiveCocoa
import ReactiveSwift
import Nimble

public func sendValue<T: Equatable, E: Equatable>(_ value: T?, sendError: E?, complete: Bool) -> NonNilMatcherFunc<SignalProducer<T, E>> {
	return sendValues(value.map { [$0] } ?? [], sendError: sendError, complete: complete)
}

public func sendValues<T: Equatable, E: Equatable>(_ values: [T], sendError maybeSendError: E?, complete: Bool) -> NonNilMatcherFunc<SignalProducer<T, E>> {
	return NonNilMatcherFunc { actualExpression, failureMessage in
		precondition(maybeSendError == nil || !complete, "Signals can't both send an error and complete")

		failureMessage.postfixMessage = "Send values \(values). Send error \(maybeSendError). Complete: \(complete)"
		let maybeProducer = try actualExpression.evaluate()

		if let signalProducer = maybeProducer {
			var sentValues: [T] = []
			var sentError: E?
			var signalCompleted = false

			signalProducer.start { event in
				switch event {
				case let .value(value):
					sentValues.append(value)
				case .completed:
					signalCompleted = true
				case let .failed(error):
					sentError = error
				default:
					break
				}
			}

			if sentValues != values {
				return false
			}

			if sentError != maybeSendError {
				return false
			}

			return signalCompleted == complete
		}
		else {
			return false
		}
	}
}
