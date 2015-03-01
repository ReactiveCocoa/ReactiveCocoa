//
//  SignalProducerNimbleMatchers.swift
//  ReactiveCocoa
//
//  Created by Javier Soto on 1/25/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

import ReactiveCocoa
import Nimble

public func sendValue<T: Equatable, E: Equatable>(value: T?, #sendError: E?, #complete: Bool) -> NonNilMatcherFunc<SignalProducer<T, E>> {
	return sendValues(value.map { [$0] } ?? [], sendError: sendError, complete: complete)
}

public func sendValues<T: Equatable, E: Equatable>(values: [T], sendError maybeSendError: E?, #complete: Bool) -> NonNilMatcherFunc<SignalProducer<T, E>> {
	return NonNilMatcherFunc { actualExpression, failureMessage in
		precondition(maybeSendError == nil || !complete, "Signals can't both send an error and complete")

		failureMessage.postfixMessage = "Send values \(values). Send error \(maybeSendError). Complete: \(complete)"
		let maybeProducer = actualExpression.evaluate()

		if let signalProducer = maybeProducer {
			var sentValues: [T] = []
			var sentError: E?
			var signalCompleted = false

			signalProducer.start(next: { value in
				sentValues.append(value)
			}, error: { error in
				sentError = error
			}, completed: {
				signalCompleted = true
			})

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