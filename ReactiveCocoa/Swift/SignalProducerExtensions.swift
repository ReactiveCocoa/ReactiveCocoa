//
//  SignalProducerExtensions.swift
//  ReactiveCocoa
//
//  Created by Nate Stedman on 3/22/16.
//  Copyright © 2016 GitHub. All rights reserved.
//

import enum Result.NoError

extension SignalProducer {
	func demoteErrors() -> SignalProducer<Value, NoError> {
		return flatMapError { _ in SignalProducer<Value, NoError>.empty }
	}
}

extension SignalProducer {
	func constrainToType<T>(type: T.Type) -> SignalProducer<T, Error> {
		return map({ $0 as? T }).ignoreNil()
	}
}
