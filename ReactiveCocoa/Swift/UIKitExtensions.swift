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
