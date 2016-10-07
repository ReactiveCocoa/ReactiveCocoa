//
//  UIBarButtonItem.swift
//  Rex
//
//  Created by Bjarke Hesthaven Søndergaard on 24/07/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactive where Base: UIBarButtonItem {
	private var associatedAction: Atomic<CocoaAction<Base>?> {
		return associatedValue { _ in Atomic(nil) }
	}

	public var pressed: CocoaAction<Base>? {
		get {
			return associatedAction.value
		}

		nonmutating set {
			associatedAction.value = newValue
			base.target = newValue
			base.action = newValue.map { _ in CocoaAction<Base>.selector }
		}
	}
}
