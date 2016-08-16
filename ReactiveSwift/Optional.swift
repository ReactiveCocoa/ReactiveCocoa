//
//  Optional.swift
//  ReactiveSwift
//
//  Created by Neil Pankey on 6/24/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

/// An optional protocol for use in type constraints.
public protocol OptionalProtocol {
	/// The type contained in the otpional.
	associatedtype Wrapped

	init(reconstructing value: Wrapped?)

	/// Extracts an optional from the receiver.
	var optional: Wrapped? { get }
}

extension Optional: OptionalProtocol {
	public var optional: Wrapped? {
		return self
	}

	public init(reconstructing value: Wrapped?) {
		self = value
	}
}

extension SignalProtocol {
	/// Turns each value into an Optional.
	internal func optionalize() -> Signal<Value?, Error> {
		return map(Optional.init)
	}
}

extension SignalProducerProtocol {
	/// Turns each value into an Optional.
	internal func optionalize() -> SignalProducer<Value?, Error> {
		return lift { $0.optionalize() }
	}
}
