//
//  NSPopUpButton.swift
//  ReactiveCocoa
//
//  Created by Seil Oh on 2016. 12. 13..
//  Copyright © 2016년 GitHub. All rights reserved.
//

import ReactiveSwift
import AppKit
import enum Result.NoError

extension Reactive where Base: NSPopUpButton {
	
	/// A signal of selected indexes
	public var selectedIndexes: Signal<Int, NoError> {
		return self.integerValues.map { [unowned base = self.base] _ -> Int? in
			guard let item = base.selectedItem else { return nil }
			return base.index(of: item)
		}
		.skipNil()
	}
	/// Sets the button with an index.
	public var selectedIndex: BindingTarget<Int> {
		return makeBindingTarget { $0.selectItem(at: $1) }
	}
	
	/// A signal of selected title
	public var selectedTitles: Signal<String, NoError> {
		return self.integerValues.map { [unowned base = self.base] _ -> String? in
			return base.selectedItem?.title
		}
		.skipNil()
	}
	
	/// Sets the button with title.
	public var selectedTitle: BindingTarget<String> {
		return makeBindingTarget { $0.selectItem(withTitle: $1) }
	}
}
