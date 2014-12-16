//
//  Action.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-01.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit

/// Represents a UI action that will perform some work when executed.
public final class Action<Input, Output> {
	private let executeClosure: Input -> ColdSignal<Output>
	private let scheduler: Scheduler

	private let _executing = ObservableProperty(false)
	private let _enabled = ObservableProperty(false)
	private let _values: SinkOf<Output>
	private let _errors: SinkOf<NSError>

	/// Whether the action is currently executing.
	///
	/// This will send the current value immediately, then all future values on
	/// the scheduler given at initialization time.
	public var executing: ColdSignal<Bool> {
		return _executing.values
	}

	/// Whether the action is enabled.
	///
	/// This will send the current value immediately, then all future values on
	/// the scheduler given at initialization time.
	public var enabled: ColdSignal<Bool> {
		return _enabled.values
	}

	/// A signal of all values generated from future calls to execute(), sent on
	/// the scheduler given at initialization time.
	public let values: HotSignal<Output>

	/// A signal of errors generated from future executions, sent on the
	/// scheduler given at initialization time.
	public let errors: HotSignal<NSError>

	/// The file in which this action was defined, if known.
	internal let file: String?

	/// The function in which this action was defined, if known.
	internal let function: String?

	/// The line number upon which this action was defined, if known.
	internal let line: Int?

	/// Initializes an action that will be conditionally enabled, and create
	/// a ColdSignal for each execution.
	///
	/// Before `enabledIf` sends a value, the command will be disabled.
	public init(enabledIf: HotSignal<Bool>, serializedOnScheduler scheduler: Scheduler, _ execute: Input -> ColdSignal<Output>, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		self.file = file
		self.line = line
		self.function = function
		self.scheduler = scheduler

		(values, _values) = HotSignal.pipe()
		(errors, _errors) = HotSignal.pipe()
		executeClosure = execute

		_enabled <~! ColdSignal.single(false)
			.concat(enabledIf
				.replay(1)
				.deliverOn(scheduler))
			.combineLatestWith(executing)
			.map { enabled, executing in enabled && !executing }
	}

	/// Initializes an action that will deliver all events on the main thread.
	public convenience init(enabledIf: HotSignal<Bool>, _ execute: Input -> ColdSignal<Output>, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		self.init(enabledIf: enabledIf, serializedOnScheduler: MainScheduler(), execute, file: file, line: line, function: function)
	}

	/// Initializes an action that will always be enabled.
	public convenience init(serializedOnScheduler: Scheduler, _ execute: Input -> ColdSignal<Output>, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		let (enabled, enabledSink) = HotSignal<Bool>.pipe()
		self.init(enabledIf: enabled, serializedOnScheduler: serializedOnScheduler, execute, file: file, line: line, function: function)

		enabledSink.put(true)
	}

	/// Initializes an action that will always be enabled, and deliver all
	/// events on the main thread.
	public convenience init(_ execute: Input -> ColdSignal<Output>, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		self.init(serializedOnScheduler: MainScheduler(), execute, file: file, line: line, function: function)
	}

	/// Creates a signal that will execute the action on the scheduler given at
	/// initialization time, with the given input, then forward the results.
	///
	/// If the action is disabled when the returned signal is subscribed to,
	/// the signal will send an `NSError` corresponding to
	/// `RACError.ActionNotEnabled`, and no result will be sent along the action
	/// itself.
	public func execute(input: Input) -> ColdSignal<Output> {
		return ColdSignal<Output>.lazy {
				let isEnabled = self.enabled.first().value()!
				if (!isEnabled) {
					return .error(RACError.ActionNotEnabled.error)
				}

				return self.executeClosure(input)
					.deliverOn(self.scheduler)
					.on(subscribed: {
						self._executing.value = true
					}, next: { value in
						self._values.put(value)
					}, error: { error in
						self._errors.put(error)
					}, disposed: {
						self._executing.value = false
					})
			}
			.subscribeOn(scheduler)
	}
}

extension Action: DebugPrintable {
	public var debugDescription: String {
		return "\(function).Action (\(file):\(line))"
	}
}
