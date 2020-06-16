#if canImport(UIKit) && !os(tvOS) && !os(watchOS)
import ReactiveSwift
import UIKit

private class SearchBarDelegateProxy: DelegateProxy<UISearchBarDelegate>, UISearchBarDelegate {
	@objc func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		forwardee?.searchBarTextDidBeginEditing?(searchBar)
	}

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
		// TODO: Mac Catalyst UISearchBarDelegate issue
		// Related: https://github.com/ReactiveX/RxSwift/issues/2161
		_ = DelegateProxy<UISearchBarDelegate>.self

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
	public var textValues: Signal<String?, Never> {
		return proxy.intercept(#selector(UISearchBarDelegate.searchBarTextDidEndEditing))
			.map { [unowned base] in base.text }
	}

	/// A signal of text values emitted by the search bar upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String?, Never> {
		return proxy.intercept(#selector(proxy.searchBar(_:textDidChange:)))
			.map { [unowned base] in base.text }
	}

	/// A signal of the latest selected scope button index upon any user selection.
	public var selectedScopeButtonIndices: Signal<Int, Never> {
		return proxy.intercept(#selector(proxy.searchBar(_:selectedScopeButtonIndexDidChange:)))
			.map { $0[1] as! Int }
	}

	/// A void signal emitted by the search bar upon any click on the cancel button
	public var cancelButtonClicked: Signal<Void, Never> {
		return proxy.intercept(#selector(proxy.searchBarCancelButtonClicked))
	}

	/// A void signal emitted by the search bar upon any click on the search button
	public var searchButtonClicked: Signal<Void, Never> {
		return proxy.intercept(#selector(proxy.searchBarSearchButtonClicked(_:)))
	}

	/// A void signal emitted by the search bar upon any click on the bookmark button
	public var bookmarkButtonClicked: Signal<Void, Never> {
		return proxy.intercept(#selector(proxy.searchBarBookmarkButtonClicked))
	}

	/// A void signal emitted by the search bar upon any click on the bookmark button
	public var resultsListButtonClicked: Signal<Void, Never> {
		return proxy.intercept(#selector(proxy.searchBarResultsListButtonClicked))
	}

	/// A void signal emitted by the search bar upon start of editing
	public var textDidBeginEditing: Signal<Void, Never> {
		return proxy.intercept(#selector(proxy.searchBarTextDidBeginEditing))
	}

	/// A void signal emitted by the search bar upon end of editing
	public var textDidEndEditing: Signal<Void, Never> {
		return proxy.intercept(#selector(proxy.searchBarTextDidEndEditing))
	}

	/// Shows and hides the cancel button of the search bar
	public var showsCancelButton: BindingTarget<Bool> {
		return makeBindingTarget { $0.showsCancelButton = $1 }
	}
}
#endif
