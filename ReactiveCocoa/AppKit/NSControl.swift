//
//  NSControl.swift
//  ReactiveCocoa
//
//  Created by Yury Lapitsky on 7/8/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import enum Result.NoError
import AppKit

extension Reactive where Base: NSControl {
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isEnabled = $1 }
	}

	public var attributedString: BindingTarget<NSAttributedString> {
		return makeBindingTarget { $0.attributedStringValue = $1 }
	}

	public var attributedStringValues: Signal<NSAttributedString, NoError> {
		return trigger.map { [unowned base] in base.attributedStringValue }
	}

	public var boolValue: BindingTarget<Bool> {
		return makeBindingTarget { $0.integerValue = $1 ? NSOnState : NSOffState }
	}

	public var boolValues: Signal<Bool, NoError> {
		return trigger.map { [unowned base] in base.integerValue == NSOffState ? false : true }
	}

	public var doubleValue: BindingTarget<Double> {
		return makeBindingTarget { $0.doubleValue = $1 }
	}

	public var doubleValues: Signal<Double, NoError> {
		return trigger.map { [unowned base] in base.doubleValue }
	}

	public var floatValue: BindingTarget<Float> {
		return makeBindingTarget { $0.floatValue = $1 }
	}

	public var floatValues: Signal<Float, NoError> {
		return trigger.map { [unowned base] in base.floatValue }
	}

	public var intValue: BindingTarget<Int32> {
		return makeBindingTarget { $0.intValue = $1 }
	}

	public var intValues: Signal<Int32, NoError> {
		return trigger.map { [unowned base] in base.intValue }
	}

	public var integerValue: BindingTarget<Int> {
		return makeBindingTarget { $0.integerValue = $1 }
	}

	public var integerValues: Signal<Int, NoError> {
		return trigger.map { [unowned base] in base.integerValue }
	}

	public var objectValue: BindingTarget<Any?> {
		return makeBindingTarget { $0.objectValue = $1 }
	}

	public var objectValues: Signal<Any?, NoError> {
		return trigger.map { [unowned base] in base.objectValue }
	}

	public var stringValue: BindingTarget<String> {
		return makeBindingTarget { $0.stringValue = $1 }
	}

	public var stringValues: Signal<String, NoError> {
		return trigger.map { [unowned base] in base.stringValue }
	}

	private var trigger: Signal<(), NoError> {
		let receiver: ActionMessageReceiver = associatedObject(base, key: &controlTriggerKey) { base in
			let receiver = ActionMessageReceiver()
			base.target = receiver
			base.action = #selector(ActionMessageReceiver.receive)

			return receiver
		}

		return receiver.trigger
	}
}

private class ActionMessageReceiver: NSObject {
	let trigger: Signal<(), NoError>
	private let observer: Signal<(), NoError>.Observer

	override init() {
		(trigger, observer) = Signal<(), NoError>.pipe()
		super.init()
	}

	deinit {
		observer.sendCompleted()
	}

	@objc func receive(_ sender: Any?) {
		observer.send(value: ())
	}
}

var controlTriggerKey = 0
