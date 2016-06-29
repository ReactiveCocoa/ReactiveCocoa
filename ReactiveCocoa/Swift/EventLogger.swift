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
		case next, completed, failed, terminated, disposed, interrupted

		public static let allEvents: Set<Signal> = [
			.next, .completed, .failed, .terminated, .disposed, .interrupted,
		]
	}

	public enum SignalProducer: String {
		case started, next, completed, failed, terminated, disposed, interrupted

		public static let allEvents: Set<SignalProducer> = [
			.started, .next, .completed, .failed, .terminated, .disposed, .interrupted,
		]
	}
}

private func defaultEventLog(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
	print("[\(identifier)] \(event) fileName: \(fileName), functionName: \(functionName), lineNumber: \(lineNumber)")
}

public typealias EventLogger = (identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) -> Void

extension SignalProtocol {
	/// Logs all events that the receiver sends.
	/// By default, it will print to the standard output.
	public func logEvents(identifier: String = "", events: Set<LoggingEvent.Signal> = LoggingEvent.Signal.allEvents, fileName: String = #file, functionName: String = #function, lineNumber: Int = #line, logger: EventLogger = defaultEventLog) -> Signal<Value, Error> {
		func log<T>(_ event: LoggingEvent.Signal) -> ((T) -> Void)? {
			return event.logIfNeeded(events: events) { event in
				logger(identifier: identifier, event: event, fileName: fileName, functionName: functionName, lineNumber: lineNumber)
			}
		}

		return self.on(
			failed: log(.failed),
			completed: log(.completed),
			interrupted: log(.interrupted),
			terminated: log(.terminated),
			disposed: log(.disposed),
			next: log(.next)
		)
	}
}

extension SignalProducerProtocol {
	/// Logs all events that the receiver sends.
	/// By default, it will print to the standard output.
	public func logEvents(identifier: String = "", events: Set<LoggingEvent.SignalProducer> = LoggingEvent.SignalProducer.allEvents, fileName: String = #file, functionName: String = #function, lineNumber: Int = #line, logger: EventLogger = defaultEventLog) -> SignalProducer<Value, Error> {
		func log<T>(_ event: LoggingEvent.SignalProducer) -> ((T) -> Void)? {
			return event.logIfNeeded(events: events) { event in
				logger(identifier: identifier, event: event, fileName: fileName, functionName: functionName, lineNumber: lineNumber)
			}
		}

		return self.on(
			started: log(.started),
			failed: log(.failed),
			completed: log(.completed),
			interrupted: log(.interrupted),
			terminated: log(.terminated),
			disposed: log(.disposed),
			next: log(.next)
		)
	}
}

private protocol LoggingEventProtocol: Hashable, RawRepresentable {}
extension LoggingEvent.Signal: LoggingEventProtocol {}
extension LoggingEvent.SignalProducer: LoggingEventProtocol {}

private extension LoggingEventProtocol {
	func logIfNeeded<T>(events: Set<Self>, logger: (String) -> Void) -> ((T) -> Void)? {
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
