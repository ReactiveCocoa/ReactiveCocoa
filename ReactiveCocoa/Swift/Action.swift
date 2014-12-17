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

	/// A signal of all values sent upon the signals returned from apply().
	public let values: HotSignal<Output>

	/// A signal of all errors (except `RACAction.ActionNotEnabled` errors) sent
	/// upon the signals returned from apply().
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
	internal let file: String?

	/// The function in which this action was defined, if known.
	internal let function: String?

	/// The line number upon which this action was defined, if known.
	internal let line: Int?

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
		let (enabled, enabledSink) = HotSignal<Bool>.pipe()
		self.init(enabledIf: enabled, execute, file: file, line: line, function: function)

		enabledSink.put(true)
	}

	/// Creates a signal that will execute the action with the given input, then
	/// forward the results.
	///
	/// If the action is disabled when the returned signal is started, the
	/// returned signal will send an `NSError` corresponding to
	/// `RACError.ActionNotEnabled`, and nothing will be sent upon `values` or
	/// `errors`.
	public func apply(input: Input) -> ColdSignal<Output> {
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

/// Wraps an Action for use by a GUI control (such as `NSControl` or
/// `UIControl`), with KVO, or with Cocoa Bindings.
public final class CocoaAction: NSObject {
	/// Whether the action is enabled.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public var enabled: Bool {
		return _enabled
	}

	/// Whether the action is executing.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public var executing: Bool {
		return _executing
	}

	/// The selector that a caller should invoke upon the receiver in order to
	/// execute the action.
	public let selector: Selector = "execute:"

	private let _execute: AnyObject? -> ()
	private var _enabled = false
	private var _executing = false
	private let disposable = CompositeDisposable()

	private init(enabled: ColdSignal<Bool>, executing: ColdSignal<Bool>, execute: AnyObject? -> ()) {
		_execute = execute

		super.init()

		startSignalOnMainThread(enabled) { [weak self] value in
			self?.willChangeValueForKey("enabled")
			self?._enabled = value
			self?.didChangeValueForKey("enabled")
		}

		startSignalOnMainThread(executing) { [weak self] value in
			self?.willChangeValueForKey("executing")
			self?._executing = value
			self?.didChangeValueForKey("executing")
		}
	}

	/// Initializes a Cocoa action that will always invoke the given action with
	/// an input of ().
	public convenience init<Output>(_ action: Action<(), Output>) {
		self.init(enabled: action.enabled, executing: action.executing, execute: { object in
			action.apply(()).start()
			return
		})
	}

	/// Initializes a Cocoa action that will always invoke the given action with
	/// an input of nil.
	public convenience init<Input: NilLiteralConvertible, Output>(_ action: Action<Input, Output>) {
		self.init(enabled: action.enabled, executing: action.executing, execute: { object in
			action.apply(nil).start()
			return
		})
	}

	/// Initializes a Cocoa action that will invoke the given action with the
	/// object given to execute() if it can be downcast successfully, or nil
	/// otherwise.
	public convenience init<Input: AnyObject, Output>(_ action: Action<Input?, Output>) {
		self.init(enabled: action.enabled, executing: action.executing, execute: { object in
			action.apply(object as? Input).start()
			return
		})
	}

	deinit {
		self.disposable.dispose()
	}

	/// Starts the given signal, delivering its uniqued values to the main
	/// thread and executing the given closure for each one.
	private func startSignalOnMainThread<T: Equatable>(signal: ColdSignal<T>, next: T -> ()) {
		let signalDisposable = signal
			.skipRepeats(identity)
			.deliverOn(MainScheduler())
			.start(next: next)

		self.disposable.addDisposable(signalDisposable)
	}

	/// Attempts to execute the underlying action with the given input, subject
	/// to the behavior described by the initializer that was used.
	@IBAction public func execute(input: AnyObject?) {
		_execute(input)
	}

	public override class func automaticallyNotifiesObserversForKey(key: String) -> Bool {
		return false
	}
}
