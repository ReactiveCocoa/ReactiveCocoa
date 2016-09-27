//
//  UIViewController.swift
//  Rex
//
//  Created by Rui Peres on 14/04/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import Result
import UIKit

extension UIViewController {
	/// Returns a `Signal`, that will be triggered
	/// when `self`'s `viewDidDisappear` is called
	public var rac_viewDidDisappear: Signal<(), NoError> {
		return trigger(for: #selector(UIViewController.viewDidDisappear(_:)))
	}

	/// Returns a `Signal`, that will be triggered
	/// when `self`'s `viewWillDisappear` is called
	public var rac_viewWillDisappear: Signal<(), NoError> {
		return trigger(for: #selector(UIViewController.viewWillDisappear(_:)))
	}

	/// Returns a `Signal`, that will be triggered
	/// when `self`'s `viewDidAppear` is called
	public var rac_viewDidAppear: Signal<(), NoError> {
		return trigger(for: #selector(UIViewController.viewDidAppear(_:)))
	}

	/// Returns a `Signal`, that will be triggered
	/// when `self`'s `viewWillAppear` is called
	public var rac_viewWillAppear: Signal<(), NoError> {
		return trigger(for: #selector(UIViewController.viewWillAppear(_:)))
	}

	public typealias DismissingCompletion = ((Void) -> Void)?
	public typealias DismissingInformation = (animated: Bool, completion: DismissingCompletion)

	/// Wraps a viewController's `dismissViewControllerAnimated` function in a bindable property.
	/// It mimics the same input as `dismissViewControllerAnimated`: a `Bool` flag for the animation
	/// and a `(Void -> Void)?` closure for `completion`.
	/// E.g:
	/// ```
	/// //Dismissed with animation (`true`) and `nil` completion
	/// viewController.rac_dismissAnimated <~ aProducer.map { _ in (true, nil) }
	/// ```
	/// The dismissal observation can be made either with binding (example above)
	/// or `viewController.dismissViewControllerAnimated(true, completion: nil)`
	public var rac_dismissAnimated: BindingTarget<DismissingInformation> {
		/// TODO: Convert into `Action`?
		return bindingTarget { $0.dismiss(animated: $1.animated, completion: $1.completion) }
	}
}

private var dismissModally: UInt8 = 0
