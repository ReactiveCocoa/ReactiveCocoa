//
//  EventLogger.swift
//  ReactiveCocoa
//
//  Created by Rui Peres on 30/04/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation

public enum LoggingEvent: String {
	case Started, Next, Completed, Failed, Terminated, Disposed, Interrupted
	
	public static let allEvents: Set<LoggingEvent> = {
		return [.Started, .Next, .Completed, .Failed, .Terminated, .Disposed, .Interrupted]
	}()
}

private func printLog(event: String, fileName: String, functionName: String, lineNumber: Int) -> Void {
	print("\(event) fileName: \(fileName), functionaName: \(functionName), lineNumber: \(lineNumber)")
}

public typealias EventLogger = (event: String, fileName: String, functionName: String, lineNumber: Int) -> Void
typealias OptionalClosure = (Void -> Void)?

extension SignalType {
	/// Logs all events that the receiver sends.
	/// By default, it will print to the standard output.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func logEvents(identifier: String = "", events: Set<LoggingEvent> = LoggingEvent.allEvents, fileName: String = #file, functionName: String = #function, lineNumber: Int = #line, logger: EventLogger = printLog) -> Signal<Value, Error> {
		
		let logEvent: String -> Void = { event in
			logger(event: "[\(identifier)] \(event)", fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		}
		
		func log<T>(event: LoggingEvent) -> (T -> Void)? {
			return events.contains(event) ? { logEvent("\(event.rawValue) \($0)") } : nil
		}

		return self.on(failed: log(.Failed),
		               completed: log(.Completed),
		               interrupted: log(.Interrupted),
		               terminated: log(.Terminated),
		               disposed: log(.Disposed),
		               next: log(.Next))
	}
}

extension SignalProducerType {
	/// Logs all events that the receiver sends.
	/// By default, it will print to the standard output.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func logEvents(identifier: String = "", events: Set<LoggingEvent> = LoggingEvent.allEvents, fileName: String = #file, functionName: String = #function, lineNumber: Int = #line, logger: EventLogger = printLog) -> SignalProducer<Value, Error> {
		
		let logEvent: String -> Void = { event in
			logger(event: "[\(identifier)] \(event)", fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		}
		
		func log<T>(event: LoggingEvent) -> (T -> Void)? {
			return events.contains(event) ? { logEvent("\(event.rawValue) \($0)") } : nil
		}
		
		return lift { $0.logEvents(identifier, events: events, logger: logger, fileName: fileName, functionName: functionName, lineNumber: lineNumber) }
			.on(started: log(.Started))
	}
}
