import ReactiveSwift
import AppKit
import enum Result.NoError

extension Reactive where Base: NSPopUpButton {
	
	/// A signal of selected indexes
	public var selectedIndexes: Signal<Int, NoError> {
		return self.integerValues
			.map { [unowned base = self.base] _ -> Int in
				return base.indexOfSelectedItem
			}
	}
	
	/// Sets the button with an index.
	public var selectedIndex: BindingTarget<Int?> {
		return makeBindingTarget {
			$0.selectItem(at: $1 ?? -1)
		}
	}
	
	/// A signal of selected title
	public var selectedTitles: Signal<String, NoError> {
		return self.objectValues
			.map { [unowned base = self.base] _ -> String? in
				return base.titleOfSelectedItem
			}
			.skipNil()
	}
	
	/// Sets the button with title.
	/// note: emitting nil to this target will set selectedTitle to empty string
	public var selectedTitle: BindingTarget<String?> {
		return makeBindingTarget {
			$0.selectItem(withTitle: $1 ?? "")
		}
	}

	public var selectedItems: Signal<NSMenuItem, NoError> {
		return self.objectValues
			.map { [unowned base = self.base] _ -> NSMenuItem? in
				return base.selectedItem
			}
			.skipNil()
	}
}
