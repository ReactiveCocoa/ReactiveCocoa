//
//  Disposable.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// Represents something that can be “disposed,” usually associated with freeing
/// resources or canceling work.
protocol Disposable {
	/// Whether this disposable has been disposed already.
	var disposed: Bool { get }

	func dispose()
}

/// A disposable that only flips `disposed` upon disposal, and performs no other
/// work.
struct SimpleDisposable: Disposable {
	var _disposed = Atomic(false)

	var disposed: Bool {
		return _disposed
	}
	
	func dispose() {
		_disposed.value = true
	}
}

/// A disposable that will run an action upon disposal.
struct ActionDisposable: Disposable {
	var _action: Atomic<(() -> ())?>

	var disposed: Bool {
		return !_action.value
	}

	/// Initializes the disposable to run the given action upon disposal.
	init(action: () -> ()) {
		_action = Atomic(action)
	}

	func dispose() {
		let action = _action.swap(nil)
		action?()
	}
}

/// A disposable that will dispose of any number of other disposables.
struct CompositeDisposable: Disposable {
	var _disposables: Atomic<[Disposable]?>
	
	var disposed: Bool {
		return !_disposables.value
	}

	/// Initializes a CompositeDisposable containing the given list of
	/// disposables.
	init(_ disposables: [Disposable]) {
		_disposables = Atomic(disposables)
	}

	/// Initializes an empty CompositeDisposable.
	init() {
		self.init([])
	}
	
	func dispose() {
		if let ds = _disposables.swap(nil) {
			for d in ds {
				d.dispose()
			}
		}
	}
	
	/// Adds the given disposable to the list.
	func addDisposable(d: Disposable?) {
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
	func addDisposable(action: () -> ()) {
		addDisposable(ActionDisposable(action))
	}

	/// Removes all Disposables that have already been disposed.
	///
	/// This can be used to prevent unbounded resource growth in an infinite
	/// algorithm.
	func pruneDisposed() {
		_disposables.modify { ds in
			return ds?.filter { !$0.disposed }
		}
	}
}

/// A disposable that, upon deinitialization, will automatically dispose of
/// another disposable.
@final class ScopedDisposable<D: Disposable>: Disposable {
	/// The disposable which will be disposed when the ScopedDisposable
	/// deinitializes.
	let innerDisposable: D
	
	var disposed: Bool {
		return innerDisposable.disposed
	}
	
	/// Initializes the receiver to dispose of the argument upon
	/// deinitialization.
	init(_ disposable: D) {
		innerDisposable = disposable
	}
	
	deinit {
		dispose()
	}
	
	func dispose() {
		innerDisposable.dispose()
	}
}

/// A disposable that will optionally dispose of another disposable.
@final class SerialDisposable: Disposable {
	struct _State {
		var innerDisposable: Disposable? = nil
		var disposed = false
	}

	var _state = Atomic(_State())

	var disposed: Bool {
		return _state.value.disposed
	}

	/// The inner disposable to dispose of.
	///
	/// Whenever this property is set (even to the same value!), the previous
	/// disposable is automatically disposed.
	var innerDisposable: Disposable? {
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
	init(_ disposable: Disposable? = nil) {
		innerDisposable = disposable
	}

	func dispose() {
		innerDisposable = nil
	}
}
