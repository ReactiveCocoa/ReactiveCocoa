//
//  Operators.swift
//  Rex
//
//  Created by Alexandros Salazar on 5/13/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Foundation

import Foundation
import ReactiveCocoa

infix operator --> {
associativity left

// bind as strong as assignment.
precedence 90
}

/// Sends the value as the next event. Usage:
///
///     value --> sink
///
/// - parameter value:     the next value.
/// - parameter observer:  the observer that will handle the value.
public func --><T, E>(value:T, sink:SinkOf<Event<T, E>>) {
    sendNext(sink, value)
}

/// Sends the error as an error event. Usage:
///
///     error --> sink
///
/// - parameter error:     the error to send.
/// - parameter observer:  the observer that will handle the value.
public func --><T, E>(error:E, sink:SinkOf<Event<T, E>>) {
    sendError(sink, error)
}

prefix operator --| {}

/// Sends a completed event to the sink. Usage:
///
///     --|sink
///
/// - parameter observer: the sink to whcih the signal will be sent.
public prefix func --|<T, E>(sink:SinkOf<Event<T, E>>) {
    return sendCompleted(sink)
}
