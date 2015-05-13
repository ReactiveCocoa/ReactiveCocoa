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
/// :param: value     the next value.
/// :param: observer  the observer that will handle the value.
public func --><T,E: ErrorType>(value:T, sink:SinkOf<Event<T, E>>) {
    sendNext(sink, value)
}

/// Sends the error as an error event. Usage:
///
///     error --> sink
///
/// :param: error     the error to send.
/// :param: observer  the observer that will handle the value.
public func --><T,E: ErrorType>(error:E, sink:SinkOf<Event<T, E>>) {
    sendError(sink, error)
}

prefix operator --| {}

/// Sends a completed event to the sink. Usage:
///
///     --|sink
///
/// :param: observer the sink to whcih the signal will be sent.
public prefix func --|<T, E:ErrorType>(sink:SinkOf<Event<T, E>>) {
    return sendCompleted(sink)
}


/// Adds the right-hand-side disposable to the left-hand-side
/// `CompositeDisposable`. Usage:
///
///     disposable += producer
///         |> filter { ... }
///         |> map    { ... }
///         |> start(sink)
///
/// :param: lhs a composite disposable.
/// :param: rhs a disposable, or `nil`. This is to handle situations where
///             functions may or may not return a disposable.
public func +=(lhs:CompositeDisposable, rhs:Disposable?) {
    lhs.addDisposable(rhs)
}


