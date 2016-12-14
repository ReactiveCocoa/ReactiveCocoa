import ReactiveSwift
import enum Result.NoError
import UIKit

private class ReactiveUISearchBarDelegate: NSObject, UISearchBarDelegate {

	@objc func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {}
	@objc func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {}
}

private var delegateKey: UInt8 = 0

extension Reactive where Base: UISearchBar {

	private var delegate: ReactiveUISearchBarDelegate {
		if let delegate = objc_getAssociatedObject(base, &delegateKey) as? ReactiveUISearchBarDelegate {
			return delegate
		} else if let _ = base.delegate {
			fatalError("Cannot use reactive values on UISearchBar with a custom delegate!")
		}

		let delegate = ReactiveUISearchBarDelegate()
		base.delegate = delegate
		objc_setAssociatedObject(base, &delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		return delegate
	}

	/// Sets the text of the search bar.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.text = $1 }
	}

	/// A signal of text values emitted by the search bar upon end of editing.
	///
	/// - important: Creating this Signal will make the reactive extension
	///   provider the delegate of the search bar. Setting your own delegate is
	///   not supported and will result in a runtime error.
	///
	/// - note: To observe text values that change on all editing events,
	///   see `continuousTextValues`.
	public var textValues: Signal<String?, NoError> {
		return delegate.reactive.trigger(for: #selector(UISearchBarDelegate.searchBarTextDidEndEditing))
			.map { [unowned base] in base.text }
	}

	/// A signal of text values emitted by the search bar upon any changes.
	///
	/// - important: Creating this Signal will make the reactive extension 
	///   provider the delegate of the search bar. Setting your own delegate is 
	///   not supported and will result in a runtime error.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String?, NoError> {
		return delegate.reactive.trigger(for: #selector(UISearchBarDelegate.searchBar(_:textDidChange:)))
			.map { [unowned base] in base.text }
	}
	
}
