//
//  Disposable.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// Represents something that can be “disposed,” usually associated with freeing
/// resources or canceling work.
public protocol Disposable {
	/// Whether this disposable has been disposed already.
	var disposed: Bool { get }

	func dispose()
}

/// A disposable that only flips `disposed` upon disposal, and performs no other
/// work.
public struct SimpleDisposable: Disposable {
	private var _disposed = Atomic(false)

	public var disposed: Bool {
		return _disposed != nil
	}

	public init() {}

	public func dispose() {
		_disposed.value = true
	}
}

/// A disposable that will run an action upon disposal.
public struct ActionDisposable: Disposable {
	private var action: Atomic<(() -> ())?>

	public var disposed: Bool {
		return action.value == nil
	}

	/// Initializes the disposable to run the given action upon disposal.
	public init(action: () -> ()) {
		self.action = Atomic(action)
	}

	public func dispose() {
		let oldAction = action.swap(nil)
		oldAction?()
	}
}

/// A disposable that will dispose of any number of other disposables.
public struct CompositeDisposable: Disposable {
	private var disposables: Atomic<[Disposable]?>

	public var disposed: Bool {
		return disposables.value == nil
	}

	/// Initializes a CompositeDisposable containing the given list of
	/// disposables.
	public init(_ disposables: [Disposable]) {
		self.disposables = Atomic(disposables)
	}

	/// Initializes an empty CompositeDisposable.
	public init() {
		self.init([])
	}

	public func dispose() {
		if let ds = disposables.swap(nil) {
			for d in ds {
				d.dispose()
			}
		}
	}

	/// Adds the given disposable to the list.
	public func addDisposable(d: Disposable?) {
		if d == nil {
			return
		}

		let (_, shouldDispose) = disposables.modify { ds -> ([Disposable]?, Bool) in
			if var ds = ds {
				ds.append(d!)
				return (ds, false)
			} else {
				return (nil, true)
			}
		}

		if shouldDispose {
			d!.dispose()
		}
	}

	/// Adds an ActionDisposable to the list.
	public func addDisposable(action: () -> ()) {
		addDisposable(ActionDisposable(action))
	}

	/// Removes all Disposables that have already been disposed.
	///
	/// This can be used to prevent unbounded resource growth in an infinite
	/// algorithm.
	public func pruneDisposed() {
		disposables.modify { ds in
			return ds?.filter { !$0.disposed }
		}
	}
}

/// A disposable that, upon deinitialization, will automatically dispose of
/// another disposable.
public final class ScopedDisposable<D: Disposable>: Disposable {
	/// The disposable which will be disposed when the ScopedDisposable
	/// deinitializes.
	public let innerDisposable: D

	public var disposed: Bool {
		return innerDisposable.disposed
	}

	/// Initializes the receiver to dispose of the argument upon
	/// deinitialization.
	public init(_ disposable: D) {
		innerDisposable = disposable
	}

	deinit {
		dispose()
	}

	public func dispose() {
		innerDisposable.dispose()
	}
}

/// A disposable that will optionally dispose of another disposable.
public final class SerialDisposable: Disposable {
	private struct State {
		var innerDisposable: Disposable? = nil
		var disposed = false
	}

	private var state = Atomic(State())

	public var disposed: Bool {
		return state.value.disposed
	}

	/// The inner disposable to dispose of.
	///
	/// Whenever this property is set (even to the same value!), the previous
	/// disposable is automatically disposed.
	public var innerDisposable: Disposable? {
		get {
			return state.value.innerDisposable
		}

		set(d) {
			let oldState = state.modify { (var state) in
				state.innerDisposable = d
				return state
			}

			oldState.innerDisposable?.dispose()
			if oldState.disposed {
				d?.dispose()
			}
		}
	}

	/// Initializes the receiver to dispose of the argument when the
	/// SerialDisposable is disposed.
	public init(_ disposable: Disposable? = nil) {
		innerDisposable = disposable
	}

	public func dispose() {
		innerDisposable = nil
	}
}
