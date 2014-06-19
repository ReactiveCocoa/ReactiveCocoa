//
//  ControllableObservable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// An Observable that can be manually controlled.
///
/// Instances of this class will automatically send Completed events to all
/// observers upon deinitialization.
@final class ControllableObservable<T>: Observable<T> {
	init() {
		super.init({ send in
			return nil
		})
	}

	deinit {
		send(.Completed)
	}

	func send(event: Event<T>) {
		for sendBox in _observers {
			sendBox.value(event)
		}
	}
}
