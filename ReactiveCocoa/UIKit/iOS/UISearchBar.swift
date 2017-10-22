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
	
	@objc func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		forwardee?.searchBarCancelButtonClicked?(searchBar)
	}

	@objc func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		forwardee?.searchBarSearchButtonClicked?(searchBar)
	}

	@objc func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
		forwardee?.searchBarBookmarkButtonClicked?(searchBar)
	}

	@objc func searchBarResultsListButtonClicked(_ searchBar: UISearchBar) {
		forwardee?.searchBarResultsListButtonClicked?(searchBar)
	}

	@objc func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		forwardee?.searchBar?(searchBar, selectedScopeButtonIndexDidChange: selectedScope)
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

	/// Sets the selected scope button index of the search bar.
	public var selectedScopeButtonIndex: BindingTarget<Int> {
		return makeBindingTarget { $0.selectedScopeButtonIndex = $1 }
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
		return proxy.intercept(#selector(proxy.searchBar(_:textDidChange:)))
			.map { [unowned base] in base.text }
	}

	/// A signal of the latest selected scope button index upon any user selection.
	public var selectedScopeButtonIndices: Signal<Int, NoError> {
		return proxy.intercept(#selector(proxy.searchBar(_:selectedScopeButtonIndexDidChange:)))
			.map { $0[1] as! Int }
	}

	/// A void signal emitted by the search bar upon any click on the cancel button
	public var cancelButtonClicked: Signal<Void, NoError> {
		return proxy.intercept(#selector(proxy.searchBarCancelButtonClicked))
	}

	/// A void signal emitted by the search bar upon any click on the search button
	public var searchButtonClicked: Signal<Void, NoError> {
		return proxy.intercept(#selector(proxy.searchBarSearchButtonClicked(_:)))
	}

	/// A void signal emitted by the search bar upon any click on the bookmark button
	public var bookmarkButtonClicked: Signal<Void, NoError> {
		return proxy.intercept(#selector(proxy.searchBarBookmarkButtonClicked))
	}

	/// A void signal emitted by the search bar upon any click on the bookmark button
	public var resultsListButtonClicked: Signal<Void, NoError> {
		return proxy.intercept(#selector(proxy.searchBarResultsListButtonClicked))
	}
}
