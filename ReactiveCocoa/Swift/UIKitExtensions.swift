//
//  UIKitExtensions.swift
//  ReactiveCocoa
//
//  Created by Nate Stedman on 3/22/16.
//  Copyright © 2016 GitHub. All rights reserved.
//

import UIKit
import enum Result.NoError

// MARK: - prepareForReuse
public protocol PrepareForReuseSignalProvidingType {
	var rac_prepareForReuseSignal: RACSignal! { get }
}

extension UICollectionReusableView: PrepareForReuseSignalProvidingType {}
extension UITableViewCell: PrepareForReuseSignalProvidingType {}
extension UITableViewHeaderFooterView: PrepareForReuseSignalProvidingType {}

extension PrepareForReuseSignalProvidingType {
	/// A signal producer which will send `()` whenever -prepareForReuse is invoked
	/// upon the receiver.
	public var prepareForReuseProducer: SignalProducer<(), NoError> {
		return rac_prepareForReuseSignal.toSignalProducer()
			.demoteErrors()
			.map { _ in () }
	}
}

// MARK: - producerForControlEvents
public protocol SignalForControlEventsProvidingType {
	func rac_signalForControlEvents(controlEvents: UIControlEvents) -> RACSignal!
}

extension UIControl: SignalForControlEventsProvidingType {}

extension SignalForControlEventsProvidingType {
	/// Creates a signal producer that sends the sender of the control event
	/// whenever one of the control events is triggered.
	public func producerForControlEvents(controlEvents: UIControlEvents) -> SignalProducer<Self, NoError> {
		return rac_signalForControlEvents(controlEvents).toSignalProducer()
			.demoteErrors()
			.map { $0 as? Self }
			.ignoreNil()
	}
}

// MARK: - textProducer
public protocol TextSignalProvidingType {
	func rac_textSignal() -> RACSignal!
}

extension UITextField: TextSignalProvidingType {}
extension UITextView: TextSignalProvidingType {}

extension TextSignalProvidingType {
	/// Creates and returns a signal producer for the text of the receiver,
	/// starting with the current text.
	///
	/// For underlying behavior and potential side-effects, see the
	/// documentation for the receiver's implementation of `rac_textSignal`.
	var textProducer: SignalProducer<String?, NoError> {
		return rac_textSignal().toSignalProducer()
			.demoteErrors()
			.map { $0 as? String }
	}
}

// MARK: - gestureProducer
public protocol GestureSignalProvidingType {
	func rac_gestureSignal() -> RACSignal!
}

extension UIGestureRecognizer: GestureSignalProvidingType {}

extension GestureSignalProvidingType {
	/// Returns a signal producer that sends the receiver when its gesture occurs.
	public var gestureProducer: SignalProducer<Self, NoError> {
		return rac_gestureSignal().toSignalProducer()
			.demoteErrors()
			.map { $0 as? Self }
			.ignoreNil()
	}
}
