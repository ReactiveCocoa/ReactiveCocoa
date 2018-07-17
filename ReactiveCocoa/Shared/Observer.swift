//
//  Observer.swift
//  ReactiveCocoa-macOS
//
//  Created by Jakub Olejník on 17/07/2018.
//  Copyright © 2018 GitHub. All rights reserved.
//

import ReactiveSwift

extension Signal.Observer: BindingTargetProvider {
	public var bindingTarget: BindingTarget<Value> {
		return BindingTarget(lifetime: lifetime(of: self)) { [weak self] in self?.send(value: $0) }
	}
}
