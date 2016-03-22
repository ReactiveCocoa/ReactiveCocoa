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
