//
//  Action.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-01.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// Represents a UI action that will perform some work when executed.
public final class Action<Input, Output> {
	typealias ExecutionSignal = Signal<Result<Output>?>

	/// The error that will be sent if execute() is invoked while the action is
	/// disabled.
	public var notEnabledError: NSError {
		// TODO: Put these domains and codes into constants for the whole framework.
		// TODO: Use real userInfo here.
		return NSError(domain: "RACAction", code: 1, userInfo: nil)
	}

	private let _scheduler: Scheduler
	private let _execute: Input -> Promise<Result<Output>>
	private let _executions = SignalingProperty<ExecutionSignal?>(nil)

	/// A signal of the signals returned from execute().
	///
	/// This will be non-nil while executing, nil between executions, and will
	/// only update on the main thread.
	public var executions: Signal<ExecutionSignal?> {
		return _executions
	}

	/// A signal of all success and error results from the receiver.
	///
	/// Before the first execution, the current value of this signal will be
	/// `nil`. Afterwards, it will always forward the latest results from any
	/// calls to execute() on the main thread.
	public var results: Signal<Result<Output>?> {
		return executions
			.unwrapOptionals(identity, initialValue: .constant(nil))
			.switchToLatest(identity)
	}

	/// Whether the action is currently executing.
	///
	/// This will only update on the main thread.
	public var executing: Signal<Bool> {
		return executions.map { !(!$0) }
	}

	/// Whether the action is enabled.
	///
	/// This will only update on the main thread.
	public let enabled: Signal<Bool>

	/// A signal of all successful results from the receiver.
	///
	/// This will be `nil` before the first execution and whenever an error
	/// occurs.
	public var values: Signal<Output?> {
		return results.map { maybeResult in
			return maybeResult?.result(ifSuccess: identity, ifError: { _ -> Output? in nil })
		}
	}

	/// A signal of all error results from the receiver.
	///
	/// This will be `nil` before the first execution and whenever execution
	/// completes successfully.
	public var errors: Signal<NSError?> {
		return results.map { maybeResult in
			return maybeResult?.result(ifSuccess: { _ -> NSError? in nil }, ifError: identity)
		}
	}

	/// Initializes an action that will be conditionally enabled, and create
	/// a Promise for each execution.
	public init(enabledIf: Signal<Bool>, scheduler: Scheduler = MainScheduler(), execute: Input -> Promise<Result<Output>>) {
		_execute = execute
		_scheduler = scheduler

		enabled = .constant(true)
		enabled = enabledIf
			.combineLatestWith(executing)
			.map { (enabled, executing) in enabled && !executing }
	}

	/// Initializes an action that will create a Promise for each execution.
	public convenience init(scheduler: Scheduler = MainScheduler(), execute: Input -> Promise<Result<Output>>) {
		self.init(enabledIf: .constant(true), scheduler: scheduler, execute: execute)
	}

	/// Executes the action on the main thread with the given input.
	///
	/// If the action is disabled when this method is invoked, the returned
	/// signal will be set to `notEnabledError`, and no result will be sent
	/// along the action itself.
	public func execute(input: Input) -> ExecutionSignal {
		let results = SignalingProperty<Result<Output>?>(nil)

		_scheduler.schedule {
			if (!self.enabled.current) {
				results.put(Result.Error(self.notEnabledError))
				return
			}

			let promise = self._execute(input)
			let execution: ExecutionSignal = promise.signal
				.deliverOn(self._scheduler)
				// Remove one layer of optional binding caused by the `deliverOn`.
				.unwrapOptionals(identity, initialValue: nil)

			self._executions.put(execution)
			execution.observe { maybeResult in
				results.put(maybeResult)

				if maybeResult {
					// Execution completed.
					self._executions.put(nil)
				}
			}

			promise.start()
		}

		return results
	}

	/// Returns an action that will execute the receiver, followed by the given
	/// action upon success.
	public func then<NewOutput>(action: Action<Output, NewOutput>) -> Action<Input, NewOutput> {
		let bothEnabled = enabled
			.combineLatestWith(action.enabled)
			.map { (a, b) in a && b }

		return Action<Input, NewOutput>(enabledIf: bothEnabled) { input in
			return Promise { sink in
				self
					.execute(input)
					.map { maybeResult -> Signal<Result<NewOutput>?> in
						return maybeResult.optional(ifNone: Signal.constant(nil)) { result in
							switch result {
							case let .Success(value):
								return action.execute(value)

							case let .Error(error):
								return .constant(Result.Error(error))
							}
						}
					}
					.switchToLatest(identity)
					.observe { maybeValue in
						if let value = maybeValue {
							sink.put(value)
						}
					}
				
				return ()
			}
		}
	}
}
