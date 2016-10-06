//
//  UITextView.swift
//  Rex
//
//  Created by Rui Peres on 05/04/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit
import enum Result.NoError

extension Reactive where Base: UITextView {
	/// Sends the textView's string value whenever it changes.
	public var text: SignalProducer<String, NoError> {
		return NotificationCenter.default.reactive
			.notifications(forName: .UITextViewTextDidChange, object: base)
			.map { ($0.object as? UITextView)?.text }
			.skipNil()
	}
}
