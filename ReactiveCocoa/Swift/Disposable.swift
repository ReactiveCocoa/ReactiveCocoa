//
//  Disposable.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// Represents something that can be “disposed,” usually associated with freeing
/// resources or canceling work.
public protocol Disposable: class {
	/// Whether this disposable has been disposed already.
	var disposed: Bool { get }

	func dispose()
}

/// A disposable that only flips `disposed` upon disposal, and performs no other
/// work.
public final class SimpleDisposable: Disposable {
	private let _disposed = Atomic(false)

	public var disposed: Bool {
		return _disposed.value
	}

	public init() {}

	public func dispose() {
		_disposed.value = true
	}
}

/// A disposable that will run an action upon disposal.
public final class ActionDisposable: Disposable {
	private let action: Atomic<(() -> ())?>

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
public final class CompositeDisposable: Disposable {
	private let disposables: Atomic<Bag<Disposable>?>

	/// Represents a handle to a disposable previously added to a
	/// CompositeDisposable.
	public final class DisposableHandle {
		private let bagToken: Atomic<RemovalToken?>
		private weak var disposable: CompositeDisposable?

		private static let empty = DisposableHandle()

		private init() {
			self.bagToken = Atomic(nil)
		}

		private init(bagToken: RemovalToken, disposable: CompositeDisposable) {
			self.bagToken = Atomic(bagToken)
			self.disposable = disposable
		}

		/// Removes the pointed-to disposable from its CompositeDisposable.
		///
		/// This is useful to minimize memory growth, by removing disposables
		/// that are no longer needed.
		public func remove() {
			if let token = bagToken.swap(nil) {
				disposable?.disposables.modify { bag in
					guard let immutableBag = bag else { return nil }
					var mutableBag = immutableBag

					mutableBag.removeValueForToken(token)
					return mutableBag
				}
			}
		}
	}

	public var disposed: Bool {
		return disposables.value == nil
	}

	/// Initializes a CompositeDisposable containing the given sequence of
	/// disposables.
	public init<S: SequenceType where S.Generator.Element == Disposable>(_ disposables: S) {
		var bag: Bag<Disposable> = Bag()

		for disposable in disposables {
			bag.insert(disposable)
		}

		self.disposables = Atomic(bag)
	}

	/// Initializes an empty CompositeDisposable.
	public convenience init() {
		self.init([])
	}

	public func dispose() {
		if let ds = disposables.swap(nil) {
			for d in ds.reverse() {
				d.dispose()
			}
		}
	}

	/// Adds the given disposable to the list, then returns a handle which can
	/// be used to opaquely remove the disposable later (if desired).
	public func addDisposable(d: Disposable?) -> DisposableHandle {
		guard let d = d else {
			return DisposableHandle.empty
		}

		var handle: DisposableHandle? = nil
		disposables.modify { ds in
			guard let immutableDs = ds else { return nil }
			var mutableDs = immutableDs

			let token = mutableDs.insert(d)
			handle = DisposableHandle(bagToken: token, disposable: self)

			return mutableDs
		}

		if let handle = handle {
			return handle
		} else {
			d.dispose()
			return DisposableHandle.empty
		}
	}

	/// Adds an ActionDisposable to the list.
	public func addDisposable(action: () -> ()) -> DisposableHandle {
		return addDisposable(ActionDisposable(action: action))
	}
}

/// A disposable that, upon deinitialization, will automatically dispose of
/// another disposable.
public final class ScopedDisposable: Disposable {
	/// The disposable which will be disposed when the ScopedDisposable
	/// deinitializes.
	public let innerDisposable: Disposable

	public var disposed: Bool {
		return innerDisposable.disposed
	}

	/// Initializes the receiver to dispose of the argument upon
	/// deinitialization.
	public init(_ disposable: Disposable) {
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

	private let state = Atomic(State())

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
			let oldState = state.modify { state in
				var mutableState = state
				mutableState.innerDisposable = d
				return mutableState
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
		let orig = state.swap(State(innerDisposable: nil, disposed: true))
		orig.innerDisposable?.dispose()
	}
}

/// Adds the right-hand-side disposable to the left-hand-side
/// `CompositeDisposable`.
///
///     disposable += producer
///         .filter { ... }
///         .map    { ... }
///         .start(observer)
///
public func +=(lhs: CompositeDisposable, rhs: Disposable?) -> CompositeDisposable.DisposableHandle {
	return lhs.addDisposable(rhs)
}
