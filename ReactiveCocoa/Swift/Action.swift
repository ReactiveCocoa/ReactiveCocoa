//
//  Action.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-01.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit

/// Represents an action that will perform side effects or a transformation when
/// executed with an input.
///
/// Actions must be executed serially. An attempt to execute the same action
/// multiple times concurrently will fail.
public final class Action<Input, Output> {
	private let executeClosure: Input -> ColdSignal<Output>
	private let valuesSink: SinkOf<Output>
	private let errorsSink: SinkOf<NSError>

	/// A signal of all values generated from future calls to execute(), sent on
	/// the scheduler given at initialization time.
	public let values: HotSignal<Output>

	/// A signal of errors generated from future executions, sent on the
	/// scheduler given at initialization time.
	public let errors: HotSignal<NSError>

	/// Whether the action is currently executing.
	///
	/// This signal will send the current value immediately (if the action is
	/// alive), and complete when the action has deinitialized.
	public var executing: ColdSignal<Bool> {
		return executingProperty.values
	}

	/// Whether the action is enabled.
	///
	/// This signal will send the current value immediately (if the action is
	/// alive), and complete when the action has deinitialized.
	public var enabled: ColdSignal<Bool> {
		return userEnabledProperty.values
			.combineLatestWith(executingProperty.values)
			.map(enabled)
	}

	// This queue serializes access to the properties below.
	//
	// Work which depends on consistent reads and writes of both properties
	// should be enqueued as a barrier block.
	//
	// If only one property is being used, the work can be enqueued as a normal
	// (non-barrier) block.
	private let propertyQueue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.Action", DISPATCH_QUEUE_SERIAL)
	private let userEnabledProperty = ObservableProperty(false)
	private let executingProperty = ObservableProperty(false)

	/// Whether the action should be enabled when `userEnabledProperty` and
	/// `executingProperty` have the given values.
	private func enabled(#userEnabled: Bool, executing: Bool) -> Bool {
		return userEnabled && !executing
	}

	/// The file in which this action was defined, if known.
	public let file: String?

	/// The function in which this action was defined, if known.
	public let function: String?

	/// The line number upon which this action was defined, if known.
	public let line: Int?

	/// Initializes an action that will be conditionally enabled, and create
	/// a ColdSignal for each execution.
	///
	/// Before `enabledIf` sends a value, the command will be disabled.
	public init(enabledIf: HotSignal<Bool>, _ execute: Input -> ColdSignal<Output>, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		self.file = file
		self.line = line
		self.function = function

		(values, valuesSink) = HotSignal.pipe()
		(errors, errorsSink) = HotSignal.pipe()
		executeClosure = execute

		userEnabledProperty <~ enabledIf
	}

	/// Initializes an action that will always be enabled.
	public convenience init(_ execute: Input -> ColdSignal<Output>, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		self.init(execute, file: file, line: line, function: function)
	}

	/// Creates a signal that will execute the action with the given input, then
	/// forward the results.
	///
	/// If the action is disabled when the returned signal is started, the
	/// returned signal will send an `NSError` corresponding to
	/// `RACError.ActionNotEnabled`, and nothing will be sent upon `values` or
	/// `errors`.
	public func execute(input: Input) -> ColdSignal<Output> {
		return ColdSignal<Output>.lazy {
			var startedExecuting = false

			dispatch_barrier_sync(self.propertyQueue) {
				if self.enabled(userEnabled: self.userEnabledProperty.value, executing: self.executingProperty.value) {
					self.executingProperty.value = true
					startedExecuting = true
				}
			}

			if !startedExecuting {
				return .error(RACError.ActionNotEnabled.error)
			}

			return self.executeClosure(input)
				.on(next: { value in
					self.valuesSink.put(value)
				}, error: { error in
					self.errorsSink.put(error)
				}, disposed: {
					// This doesn't need to be a barrier because properties are
					// themselves serialized, and this operation therefore won't
					// conflict with other read-only or write-only operations.
					//
					// We still need to use the queue for mutual exclusion with
					// the enabledness check above.
					dispatch_async(self.propertyQueue) {
						self.executingProperty.value = false
					}
				})
		}
	}
}

extension Action: DebugPrintable {
	public var debugDescription: String {
		let function = self.function ?? ""
		let file = self.file ?? ""
		let line = self.line?.description ?? ""

		return "\(function).Action (\(file):\(line))"
	}
}
