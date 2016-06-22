//
//  EventLogger.swift
//  ReactiveCocoa
//
//  Created by Rui Peres on 30/04/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation

/// A namespace for logging event types.
public enum LoggingEvent {
	public enum Signal: String {
		case Next, Completed, Failed, Terminated, Disposed, Interrupted

		public static let allEvents: Set<Signal> = [
			.Next, .Completed, .Failed, .Terminated, .Disposed, .Interrupted,
		]
	}

	public enum SignalProducer: String {
		case Started, Next, Completed, Failed, Terminated, Disposed, Interrupted

		public static let allEvents: Set<SignalProducer> = [
			.Started, .Next, .Completed, .Failed, .Terminated, .Disposed, .Interrupted,
		]
	}
}

private func defaultEventLog(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
	print("[\(identifier)] \(event) fileName: \(fileName), functionName: \(functionName), lineNumber: \(lineNumber)")
}

/// A type that represents an event logging function.
public typealias EventLogger = (identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) -> Void

extension SignalType {
	/// Logs all events that the receiver sends. By default, it will print to 
	/// the standard output.
	///
	/// - parameters:
	///   - identifier: a string to identify the Signal firing events.
	///   - events: Types of events to log.
	///   - fileName: Name of the file containing the code which fired the
	///               event.
	///   - functionName: Function where event was fired.
	///   - lineNumber: Line number where event was fired.
	///   - logger: Logger that logs the events.
	///
	/// - returns: Signal that, when observed, logs the fired events.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func logEvents(identifier identifier: String = "", events: Set<LoggingEvent.Signal> = LoggingEvent.Signal.allEvents, fileName: String = #file, functionName: String = #function, lineNumber: Int = #line, logger: EventLogger = defaultEventLog) -> Signal<Value, Error> {
		func log<T>(event: LoggingEvent.Signal) -> (T -> Void)? {
			return event.logIfNeeded(events) { event in
				logger(identifier: identifier, event: event, fileName: fileName, functionName: functionName, lineNumber: lineNumber)
			}
		}

		return self.on(
			failed: log(.Failed),
			completed: log(.Completed),
			interrupted: log(.Interrupted),
			terminated: log(.Terminated),
			disposed: log(.Disposed),
			next: log(.Next)
		)
	}
}

extension SignalProducerType {
	/// Logs all events that the receiver sends. By default, it will print to 
	/// the standard output.
	///
	/// - parameters:
	///   - identifier: a string to identify the SignalProducer firing events.
	///   - events: Types of events to log.
	///   - fileName: Name of the file containing the code which fired the
	///               event.
	///   - functionName: Function where event was fired.
	///   - lineNumber: Line number where event was fired.
	///   - logger: Logger that logs the events.
	///
	/// - returns: Signal producer that, when started, logs the fired events.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func logEvents(identifier identifier: String = "", events: Set<LoggingEvent.SignalProducer> = LoggingEvent.SignalProducer.allEvents, fileName: String = #file, functionName: String = #function, lineNumber: Int = #line, logger: EventLogger = defaultEventLog) -> SignalProducer<Value, Error> {
		func log<T>(event: LoggingEvent.SignalProducer) -> (T -> Void)? {
			return event.logIfNeeded(events) { event in
				logger(identifier: identifier, event: event, fileName: fileName, functionName: functionName, lineNumber: lineNumber)
			}
		}

		return self.on(
			started: log(.Started),
			failed: log(.Failed),
			completed: log(.Completed),
			interrupted: log(.Interrupted),
			terminated: log(.Terminated),
			disposed: log(.Disposed),
			next: log(.Next)
		)
	}
}

private protocol LoggingEventType: Hashable, RawRepresentable {}
extension LoggingEvent.Signal: LoggingEventType {}
extension LoggingEvent.SignalProducer: LoggingEventType {}

private extension LoggingEventType {
	func logIfNeeded<T>(events: Set<Self>, logger: String -> Void) -> (T -> Void)? {
		guard events.contains(self) else {
			return nil
		}

		return { value in
			if value is Void {
				logger("\(self.rawValue)")
			} else {
				logger("\(self.rawValue) \(value)")
			}
		}
	}
}
