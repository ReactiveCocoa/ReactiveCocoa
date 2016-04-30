//
//  EventLogger.swift
//  ReactiveCocoa
//
//  Created by Rui Peres on 30/04/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation

/// Used with the `debug` operator to customize
/// the `Event` string.
///
/// This is useful, when you want to do more than
/// just printing to the standard output.
public protocol EventLogger {
	func logEvent(event: String, fileName: String, functionName: String, lineNumber: Int)
}

extension EventLogger {
	func logEvent(event: String, fileName: String = #file, functionName: String = #function, lineNumber: Int = #line) {
		print("\(event) fileName: \(fileName), functionaName: \(functionName), lineNumber: \(lineNumber)")
	}
}

public enum LoggingEvent: String {
	case Started, Next, Completed, Failed, Terminated, Disposed, Interrupted
	
	public static let allEvents: Set<LoggingEvent> = {
		return [.Started, .Next, .Completed, .Failed, .Terminated, .Disposed, .Interrupted]
	}()
}

private func createEventLog(event: LoggingEvent, events: Set<LoggingEvent>, logEvent: String -> Void) -> (Void -> Void)? {
	return events.contains(event) ? { logEvent("\(event.rawValue)") } : nil
}

private func createEventLog<T>(event: LoggingEvent, events: Set<LoggingEvent>, logEvent: String -> Void) -> (T -> Void)? {
	return events.contains(event) ? { logEvent("\(event.rawValue) \($0)") } : nil
}

final class Logger: EventLogger {}

typealias OptionalClosure = (Void -> Void)?

extension SignalType {
	/// Logs all events that the receiver sends.
	/// By default, it will print to the standard output.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func logEvents(identifier: String = "", events: Set<LoggingEvent> = LoggingEvent.allEvents, logger: EventLogger = Logger(), fileName: String = #file, functionName: String = #function, lineNumber: Int = #line) -> Signal<Value, Error> {
		
		let logEvent: String -> Void = { event in
			logger.logEvent("[\(identifier)] \(event)", fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		}
		
		let failed: (Self.Error -> Void)? = createEventLog(.Failed, events: events, logEvent: logEvent)
		let completed: OptionalClosure = createEventLog(.Completed, events: events, logEvent: logEvent)
		let interrupted: OptionalClosure = createEventLog(.Interrupted, events: events, logEvent: logEvent)
		let terminated: OptionalClosure = createEventLog(.Terminated, events: events, logEvent: logEvent)
		let disposed: OptionalClosure = createEventLog(.Disposed, events: events, logEvent: logEvent)
		let next: (Self.Value -> Void)? = createEventLog(.Next, events: events, logEvent: logEvent)

		return self.on(failed: failed, completed: completed, interrupted: interrupted, terminated: terminated, disposed: disposed, next: next)
	}
}

extension SignalProducerType {
	/// Logs all events that the receiver sends.
	/// By default, it will print to the standard output.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func logEvents(identifier: String = "", events: Set<LoggingEvent> = LoggingEvent.allEvents, logger: EventLogger = Logger(), fileName: String = #file, functionName: String = #function, lineNumber: Int = #line) -> SignalProducer<Value, Error> {
		
		let logEvent: String -> Void = { event in
			logger.logEvent("[\(identifier)] \(event)", fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		}
		
		let started: OptionalClosure = createEventLog(.Started, events: events, logEvent: logEvent)
		
		return lift { $0.logEvents(identifier, events: events, logger: logger, fileName: fileName, functionName: functionName, lineNumber: lineNumber) }
			.on(started: started)
	}
}
