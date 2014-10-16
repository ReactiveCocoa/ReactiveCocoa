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
	private let executionsSink: SinkOf<ColdSignal<Output>>

	/// A signal of the signals returned from execute().
	///
	/// This will only fire on the main thread.
	public let executions: HotSignal<ColdSignal<Output>>

	/// A signal of all success and error results from the receiver.
	///
	/// This signal will forward the latest results from any calls to execute()
	/// on the main thread.
	public var results: HotSignal<Result<Output>> {
		return executions
			.unwrapOptionals(identity, initialValue: .constant(nil))
			.switchToLatest(identity)
	}

	/// Whether the action is currently executing.
	///
	/// This will send the current value immediately, then all future values on
	/// the main thread.
	public var executing: ColdSignal<Bool> {
		return executions.map { $0 != nil }
	}

	/// Whether the action is enabled.
	///
	/// This will send the current value immediately, then all future values on
	/// the main thread.
	public let enabled: ColdSignal<Bool>

	/// A signal of all successful results from the receiver, sent on the main
	/// thread.
	public var values: HotSignal<Output> {
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

	/// A signal of all error results from the receiver, sent on the main
	/// thread.
	public var errors: HotSignal<NSError> {
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
	/// a ColdSignal for each execution.
	///
	/// Before `enabledIf` sends a value, the command will be disabled.
	public init(enabledIf: HotSignal<Bool>, execute: Input -> ColdSignal<Output>) {
		(executions, executionsSink) = Signal.pipeWithInitialValue(nil)
		executeClosure = execute

		enabled = .constant(true)
		enabled = enabledIf
			.combineLatestWith(executing)
			.map { (enabled, executing) in enabled && !executing }
	}

	/// Initializes an action that will always be enabled, and create a
	/// ColdSignal for each execution.
	public convenience init(execute: Input -> ColdSignal<Output>) {
		let (enabled, enabledSink) = HotSignal.pipe()
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
		let results = SignalingProperty<Result<Output>?>(nil)

		MainScheduler().schedule {
			if (!self.enabled.current) {
				results.put(Result.Failure(RACError.ActionNotEnabled.error))
				return
			}

			let promise = self.executeClosure(input)
			let execution: ExecutionSignal = promise.signal
				.deliverOn(MainScheduler())
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
