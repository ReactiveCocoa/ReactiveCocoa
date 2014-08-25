//
//  SignalingProperty.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-26.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// Represents a mutable property of type T along with the changes to its value.
public final class SignalingProperty<T>: SinkType {
	public typealias Element = T

	private let sink: SinkOf<T>

	/// A signal representing the current value of the property, along with all
	/// changes to it over time.
	public let signal: Signal<T>

	/// The current value of the property.
    public var value: T {
		get {
			return signal.current
		}

		set(newValue) {
			sink.put(newValue)
		}
	}

	/// Initializes the property with the given default value.
	public init(_ defaultValue: T) {
		(signal, sink) = Signal.pipeWithInitialValue(defaultValue)
	}

	public func put(value: T) {
		self.value = value
	}
}
