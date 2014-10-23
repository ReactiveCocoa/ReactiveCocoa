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
	private let _executing = ObservableProperty(false)
	private let _values: SinkOf<Output>
	private let _errors: SinkOf<NSError>

	/// Whether the action is currently executing.
	///
	/// This will send the current value immediately, then all future values on
	/// the main thread.
	public let executing: ColdSignal<Bool>

	/// Whether the action is enabled.
	///
	/// This will send the current value immediately, then all future values on
	/// the main thread.
	public let enabled: ColdSignal<Bool>

	/// A signal of all values generated from future calls to execute(), sent on
	/// the main thread.
	public let values: HotSignal<Output>

	/// A signal of errors generated from future executions, sent on the main
	/// thread.
	public let errors: HotSignal<NSError>

	/// Initializes an action that will be conditionally enabled, and create
	/// a ColdSignal for each execution.
	///
	/// Before `enabledIf` sends a value, the command will be disabled.
	public init(enabledIf: HotSignal<Bool>, execute: Input -> ColdSignal<Output>) {
		(values, _values) = HotSignal.pipe()
		(errors, _errors) = HotSignal.pipe()
		executeClosure = execute

		executing = _executing.values()

		// Fires when the `executing` signal terminates.
		let executingTerminated = executing.then(.single(()))
			.startMulticasted(errorHandler: nil)

		enabled = enabledIf.replay(1)
			.deliverOn(MainScheduler())
			.takeUntil(executingTerminated)
			.combineLatestWith(executing)
			.map { (enabled, executing) in enabled && !executing }
	}

	/// Initializes an action that will always be enabled, and create a
	/// ColdSignal for each execution.
	public convenience init(execute: Input -> ColdSignal<Output>) {
		let (enabled, enabledSink) = HotSignal<Bool>.pipe()
		self.init(enabledIf: enabled, execute: execute)

		enabledSink.put(true)
	}

	/// Creates a signal that will execute the action on the main thread, with
	/// the given input, then forward the results.
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
					.deliverOn(MainScheduler())
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
			.subscribeOn(MainScheduler())
	}
}
