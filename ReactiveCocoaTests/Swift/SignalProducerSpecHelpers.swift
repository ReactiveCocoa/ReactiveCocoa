//
//  SignalProducerSpecHelpers.swift
//  ReactiveCocoa
//
//  Created by Nacho Soto on 2/14/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import ReactiveCocoa
import LlamaKit
import Nimble

extension SignalProducer {
	/// Creates a producer that can be started as many times as elements in `results`.
	/// Each signal will immediately send either a value or an error.
	static func tryWithResults<C: CollectionType where C.Generator.Element == Result<T, E>, C.Index.Distance == Int>(results: C) -> SignalProducer<T, E> {
		let resultCount = countElements(results)
		var operationIndex = 0

		precondition(resultCount > 0)

		let operation: () -> Result<T, E> = {
			if operationIndex < resultCount {
				return results[advance(results.startIndex, operationIndex++)]
			} else {
				fail("Operation started too many times")

				return results[advance(results.startIndex, 0)]
			}
		}

		return SignalProducer.try(operation)
	}
}
