import ReactiveSwift
import enum Result.NoError
import UIKit

private class SearchBarDelegateProxy: DelegateProxy<UISearchBarDelegate>, UISearchBarDelegate {
	@objc func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
		forwardee?.searchBarTextDidEndEditing?(searchBar)
	}

	@objc func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		forwardee?.searchBar?(searchBar, textDidChange: searchText)
	}
}

extension Reactive where Base: UISearchBar {
	private var proxy: SearchBarDelegateProxy {
		return .proxy(for: base,
		              setter: #selector(setter: base.delegate),
		              getter: #selector(getter: base.delegate))
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
		return proxy.intercept(#selector(UISearchBarDelegate.searchBarTextDidEndEditing))
			.map { [unowned base] in base.text }
	}

	/// A signal of text values emitted by the search bar upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String?, NoError> {
		return proxy.intercept(#selector(UISearchBarDelegate.searchBar(_:textDidChange:)))
			.map { [unowned base] in base.text }
	}
	
}
