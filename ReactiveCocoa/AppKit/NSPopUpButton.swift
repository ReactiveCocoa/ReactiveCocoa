import ReactiveSwift
import AppKit
import enum Result.NoError

extension Reactive where Base: NSPopUpButton {
	
	/// A signal of selected indexes
	public var selectedIndexes: Signal<Int, NoError> {
		return proxy.invoked.map { $0.indexOfSelectedItem }
	}
	
	/// Sets the button with an index.
	public var selectedIndex: BindingTarget<Int?> {
		return makeBindingTarget {
			$0.selectItem(at: $1 ?? -1)
		}
	}
	
	/// A signal of selected title
	public var selectedTitles: Signal<String, NoError> {
		return proxy.invoked.map { $0.titleOfSelectedItem }.skipNil()
	}
	
	/// Sets the button with title.
	/// note: emitting nil to this target will set selectedTitle to empty string
	public var selectedTitle: BindingTarget<String?> {
		return makeBindingTarget {
			$0.selectItem(withTitle: $1 ?? "")
		}
	}

	public var selectedItems: Signal<NSMenuItem, NoError> {
		return proxy.invoked.map { $0.selectedItem }.skipNil()
	}


	/// A signal of selected tags
	public var selectedTags: Signal<Int, NoError> {
		return proxy.invoked.map { $0.selectedTag() }
	}

	/// Sets the selected tag
	public var selectedTag: BindingTarget<Int> {
		return makeBindingTarget {
			$0.selectItem(withTag: $1)
		}
	}
}
