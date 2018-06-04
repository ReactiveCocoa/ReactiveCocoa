//
//  SignalProducerNimbleMatchers.swift
//  ReactiveSwift
//
//  Created by Javier Soto on 1/25/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

import ReactiveSwift
import Nimble

public func sendValue<T: Equatable, E: Equatable>(_ value: T?, sendError: E?, complete: Bool) -> Predicate<SignalProducer<T, E>> {
	return sendValues(value.map { [$0] } ?? [], sendError: sendError, complete: complete)
}

public func sendValues<T: Equatable, E: Equatable>(_ values: [T], sendError maybeSendError: E?, complete: Bool) -> Predicate<SignalProducer<T, E>> {
	return Predicate<SignalProducer<T, E>> { actualExpression in
		precondition(maybeSendError == nil || !complete, "Signals can't both send an error and complete")
		guard let signalProducer = try actualExpression.evaluate() else {
			let message = ExpectationMessage.fail("The SignalProducer was not created.")
				.appendedBeNilHint()
			return PredicateResult(status: .fail, message: message)
		}

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
			let message = ExpectationMessage.expectedCustomValueTo(
				"send values <\(values)>",
				"<\(sentValues)>"
			)
			return PredicateResult(status: .doesNotMatch, message: message)
		}

		if sentError != maybeSendError {
			let message = ExpectationMessage.expectedCustomValueTo(
				"send error <\(String(describing: maybeSendError))>",
				"<\(String(describing: sentError))>"
			)
			return PredicateResult(status: .doesNotMatch, message: message)
		}

		let completeMessage = complete ?
			"complete, but the producer did not complete" :
			"not to complete, but the producer completed"
		let message = ExpectationMessage.expectedTo(completeMessage)
		return PredicateResult(bool: signalCompleted == complete, message: message)
	}
}
