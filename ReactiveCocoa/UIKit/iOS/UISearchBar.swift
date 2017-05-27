import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UISearchBar {
	private var proxy: DelegateProxy<UISearchBarDelegate> {
		return proxy(forKey: #keyPath(UISearchBar.delegate))
	}

	/// Sets the text of the search bar.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.text = $1 }
	}

	/// A signal of text values emitted by the search bar upon end of editing.
	///
	/// - note: To observe text values that change on all editing events,
	///   see `continuousTextValues`.
	public var textValues: Signal<String?, NoError> {
		return proxy.reactive
			.trigger(for: #selector(proxy.delegateType.searchBarTextDidEndEditing))
			.map { [unowned base] in base.text }
	}

	/// A signal of text values emitted by the search bar upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String?, NoError> {
		return proxy.reactive
			.trigger(for: #selector(proxy.delegateType.searchBar(_:textDidChange:)))
			.map { [unowned base] in base.text }
	}
	
	/// A void signal emitted by the search bar upon any click on the cancel button
	public var cancelButtonClicked: Signal<Void, NoError> {
		return proxy.reactive.trigger(for: #selector(proxy.delegateType.searchBarCancelButtonClicked))
	}
}
