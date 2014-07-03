//
//  Disposable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents an object that can be “disposed,” usually associated with freeing
/// resources or canceling work.
@class_protocol protocol Disposable {
	/// Whether this disposable has been disposed already.
	var disposed: Bool { get }

	func dispose()
}

/// A disposable that only flips `disposed` upon disposal, and performs no other
/// work.
@final class SimpleDisposable: Disposable {
	var _disposed = Atomic(false)

	var disposed: Bool {
		get {
			return _disposed
		}
	}
	
	func dispose() {
		_disposed.value = true
	}
}

/// A disposable that will run an action upon disposal.
@final class ActionDisposable: Disposable {
	var _action: Atomic<(() -> ())?>

	var disposed: Bool {
		get {
			return _action == nil
		}
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
@final class CompositeDisposable: Disposable {
	var _disposables: Atomic<Disposable[]?>
	
	var disposed: Bool {
		get {
			return _disposables.value == nil
		}
	}

	/// Initializes a CompositeDisposable containing the given list of
	/// disposables.
	init(_ disposables: Disposable[]) {
		_disposables = Atomic(disposables)
	}

	/// Initializes an empty CompositeDisposable.
	convenience init() {
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
		if d == nil {
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
	
	/// Removes the given disposable from the list.
	func removeDisposable(d: Disposable?) {
		if d == nil {
			return
		}
	
		_disposables.modify {
			if let ds = $0 {
				return removeObjectIdenticalTo(d!, fromArray: ds)
			} else {
				return nil
			}
		}
	}
}

/// A disposable that, upon deinitialization, will automatically dispose of
/// another disposable.
@final class ScopedDisposable: Disposable {
	/// The disposable which will be disposed when the ScopedDisposable
	/// deinitializes.
	let innerDisposable: Disposable
	
	var disposed: Bool {
		get {
			return innerDisposable.disposed
		}
	}
	
	/// Initializes the receiver to dispose of the argument upon
	/// deinitialization.
	init(_ disposable: Disposable) {
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
		get {
			return _state.value.disposed
		}
	}

	/// The inner disposable to dispose of.
	///
	/// Whenever this is set to a new disposable, the old one is automatically
	/// disposed.
	var innerDisposable: Disposable? {
		get {
			return _state.value.innerDisposable
		}

		set(d) {
			_state.modify {
				var s = $0
				if s.innerDisposable === d {
					return s
				}

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
	convenience init(_ disposable: Disposable) {
		self.init()
		innerDisposable = disposable
	}

	func dispose() {
		innerDisposable = nil
	}
}
