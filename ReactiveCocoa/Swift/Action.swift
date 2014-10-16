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
	private let scheduler: Scheduler
	private let executeClosure: Input -> ColdSignal<Output>
	private let executionsSink: SinkOf<ColdSignal<Output>>

	/// A signal of the signals returned from execute().
	///
	/// This will only fire on the main thread.
	public let executions: HotSignal<ColdSignal<Output>>

	/// A signal of all success and error results from the receiver.
	///
	/// This signal will forward the latest results from any calls to execute(),
	/// on the main thread.
	public var results: HotSignal<Output> {
		return executions
			.unwrapOptionals(identity, initialValue: .constant(nil))
			.switchToLatest(identity)
	}

	/// Whether the action is currently executing.
	///
	/// This will only update on the main thread.
	public var executing: HotSignal<Bool> {
        	return executions.map { $0 != nil }
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
			if let result = maybeResult {
				switch result {
				case let .Success(box):
					return box.unbox

				default:
					break
				}
			}

			return nil
		}
	}

	/// A signal of all error results from the receiver.
	///
	/// This will be `nil` before the first execution and whenever execution
	/// completes successfully.
	public var errors: Signal<NSError?> {
		return results.map { maybeResult in
			if let result = maybeResult {
				switch result {
				case let .Failure(error):
					return error

				default:
					break
				}
			}

			return nil
		}
	}

	/// Initializes an action that will be conditionally enabled, and create
	/// a Promise for each execution.
	public init(enabledIf: Signal<Bool>, scheduler: Scheduler = MainScheduler(), execute: Input -> Promise<Result<Output>>) {
		(executions, executionsSink) = Signal.pipeWithInitialValue(nil)
		executeClosure = execute
		self.scheduler = scheduler

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
	/// signal will be set to an `NSError` corresponding to
	/// `RACError.ActionNotEnabled`, and no result will be sent along the action
	/// itself.
	public func execute(input: Input) -> ExecutionSignal {
		let results = SignalingProperty<Result<Output>?>(nil)

		scheduler.schedule {
			if (!self.enabled.current) {
				results.put(Result.Failure(RACError.ActionNotEnabled.error))
				return
			}

			let promise = self.executeClosure(input)
			let execution: ExecutionSignal = promise.signal
				.deliverOn(self.scheduler)
				// Remove one layer of optional binding caused by the `deliverOn`.
				.unwrapOptionals(identity, initialValue: nil)

			self.executionsSink.put(execution)
			execution.observe { maybeResult in
				results.put(maybeResult)

				if maybeResult != nil {
					// Execution completed.
					self.executionsSink.put(nil)
				}
			}

			promise.start()
		}

		return results.signal
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
							case let .Success(box):
								return action.execute(box.unbox)

							case let .Failure(error):
								return .constant(Result.Failure(error))
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
