#if canImport(UIKit) && !os(watchOS)
import ReactiveSwift
import UIKit

extension Reactive where Base: UIViewController {
	/// Set's the title of the view controller.
	public var title: BindingTarget<String?> {
		return makeBindingTarget({ $0.title = $1 })
	}

	/// A signal that sends a value event every time `viewWillAppear` is invoked.
	public var viewWillAppear: Signal<Void, Never> {
		return trigger(for: #selector(Base.viewWillAppear))
	}

	/// A signal that sends a value event every time `viewDidAppear` is invoked.
	public var viewDidAppear: Signal<Void, Never> {
		return trigger(for: #selector(Base.viewDidAppear))
	}

	/// A signal that sends a value event every time `viewWillDisappear` is invoked.
	public var viewWillDisappear: Signal<Void, Never> {
		return trigger(for: #selector(Base.viewWillDisappear))
	}

	/// A signal that sends a value event every time `viewDidDisappear` is invoked.
	public var viewDidDisappear: Signal<Void, Never> {
		return trigger(for: #selector(Base.viewDidDisappear))
	}

	/// A signal that sends a value event every time `viewWillLayoutSubviews` is invoked.
	public var viewWillLayoutSubviews: Signal<Void, Never> {
		return trigger(for: #selector(Base.viewWillLayoutSubviews))
	}

	/// A signal that sends a value event every time `viewDidLayoutSubviews` is invoked.
	public var viewDidLayoutSubviews: Signal<Void, Never> {
		return trigger(for: #selector(Base.viewDidLayoutSubviews))
	}
}
#endif
