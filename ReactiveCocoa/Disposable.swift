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
		return _disposed
	}
	
	public func dispose() {
		_disposed.value = true
	}
}

/// A disposable that will run an action upon disposal.
public struct ActionDisposable: Disposable {
	private var _action: Atomic<(() -> ())?>

	public var disposed: Bool {
		return !_action.value
	}

	/// Initializes the disposable to run the given action upon disposal.
	public init(action: () -> ()) {
		_action = Atomic(action)
	}

	public func dispose() {
		let action = _action.swap(nil)
		action?()
	}
}

/// A disposable that will dispose of any number of other disposables.
public struct CompositeDisposable: Disposable {
	private var _disposables: Atomic<[Disposable]?>
	
	public var disposed: Bool {
		return !_disposables.value
	}

	/// Initializes a CompositeDisposable containing the given list of
	/// disposables.
	public init(_ disposables: [Disposable]) {
		_disposables = Atomic(disposables)
	}

	/// Initializes an empty CompositeDisposable.
	public init() {
		self.init([])
	}
	
	public func dispose() {
		if let ds = _disposables.swap(nil) {
			for d in ds {
				d.dispose()
			}
		}
	}
	
	/// Adds the given disposable to the list.
	public func addDisposable(d: Disposable?) {
		if !d {
			return
		}
	
		let shouldDispose: Bool = _disposables.withValue {
			if var ds = $0 {
				ds.append(d!)
				return false
			} else {
				return true
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
		_disposables.modify { ds in
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
	private struct _State {
		var innerDisposable: Disposable? = nil
		var disposed = false
	}

	private var _state = Atomic(_State())

	public var disposed: Bool {
		return _state.value.disposed
	}

	/// The inner disposable to dispose of.
	///
	/// Whenever this property is set (even to the same value!), the previous
	/// disposable is automatically disposed.
	public var innerDisposable: Disposable? {
		get {
			return _state.value.innerDisposable
		}

		set(d) {
			_state.modify {
				var s = $0

				s.innerDisposable?.dispose()
				s.innerDisposable = d
				if s.disposed {
					d?.dispose()
				}

				return s
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
