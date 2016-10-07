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
	public var text: BindingTarget<String> {
		return makeBindingTarget { $0.text = $1 }
	}

	public var textValues: Signal<String, NoError> {
		var signal: Signal<String, NoError>!

		NotificationCenter.default
			.reactive
			.notifications(forName: .UITextViewTextDidEndEditing, object: base)
			.take(during: lifetime)
			.map { ($0.object as! UITextView).text! }
			.startWithSignal { innerSignal, _ in signal = innerSignal }

		return signal
	}

	public var continuousTextValues: Signal<String, NoError> {
		var signal: Signal<String, NoError>!

		NotificationCenter.default
			.reactive
			.notifications(forName: .UITextViewTextDidChange, object: base)
			.take(during: lifetime)
			.map { ($0.object as! UITextView).text! }
			.startWithSignal { innerSignal, _ in signal = innerSignal }

		return signal
	}
}
