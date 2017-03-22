//
//  Animation.swift
//  ReactiveCocoa
//
//  Created by Brendan Conron on 3/22/17.
//  Copyright © 2017 GitHub. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import UIKit

#if os(iOS) || os(tvOS)

	extension BindingTarget {

		/// Binds a source to a target, updating and animating the target's value to the latest
		/// value sent by the source with the given duration, delay, and animation options.
		///
		/// - note: The binding will automatically terminate when the target is
		///         deinitialized, or when the source sends a `completed` event.
		///
		/// - warning: Due to the nature of how `NSLayoutConstraint` is animated by
		///            calling `view.layoutIfNeeded()`, using this method on
		///            `NSLayoutConstraint`'s `reactive.constant` property will not work
		///            and may have unexpected behavior.
		///
		///````
		/// let label = UILabel(frame: CGRect(width: 100, height: 100)
		/// let disposable = label.reactive.alpha.animate(SignalProducer(value: 0), withDuration: 2)
		///
		/// // Terminate animation early before the signal's `completed` event.
		/// disposable.dispose()
		///````
		///
		/// - Parameters:
		///   - source: A source to bind.
		///   - duration: Duration of the animation.
		///   - delay: Delay to apply.
		///   - options: Animation options.
		/// - Returns: A disposable that can be used to terminate binding before the
		///			   deinitialization of the target of the source's `completed`
		///            event.
		@discardableResult
		public func animate<Source: BindingSource>(
			source: Source,
			withDuration duration: TimeInterval,
			delay: TimeInterval = 0,
			options: UIViewAnimationOptions = [])
			-> Disposable? where Value == Source.Value, Source.Error == NoError {
				let action = bindingTarget.action
				return source.observe(Observer(value: { value in
					UIView.animate(withDuration: duration, delay: delay, options: options, animations: {
						action(value)

					}, completion: nil)
				}), during: bindingTarget.lifetime)
		}

	}

	extension BindingTarget where Value: OptionalProtocol {

		/// Binds a source to a target, updating and animating the target's value to the latest
		/// value sent by the source with the given duration, delay, and animation options.
		///
		/// - note: The binding will automatically terminate when the target is
		///         deinitialized, or when the source sends a `completed` event.
		///
		/// - warning: Due to the nature of how `NSLayoutConstraint` is animated by
		///            calling `view.layoutIfNeeded()`, using this method on
		///            `NSLayoutConstraint`'s `reactive.constant` property will not work
		///            and may have unexpected behavior.
		///
		///````
		/// let label = UILabel(frame: CGRect(width: 100, height: 100)
		/// let disposable = label.reactive.alpha.animate(SignalProducer(value: 0), withDuration: 2)
		///
		/// // Terminate animation early before the signal's `completed` event.
		/// disposable.dispose()
		///````
		///
		/// - Parameters:
		///   - source: A source to bind.
		///   - duration: Duration of the animation.
		///   - delay: Delay to apply.
		///   - options: Animation options.
		/// - Returns: A disposable that can be used to terminate binding before the
		///			   deinitialization of the target of the source's `completed`
		///            event.
		@discardableResult
		public func animate<Source: BindingSource>(
			source: Source,
			withDuration duration: TimeInterval,
			delay: TimeInterval = 0, options:
			UIViewAnimationOptions = [])
			-> Disposable? where Value: OptionalProtocol, Source.Value == Value.Wrapped, Source.Error == NoError {
				let action = bindingTarget.action
				return source.observe(Observer(value: { value in
					UIView.animate(withDuration: duration, delay: delay, options: options, animations: {
						action(Value(reconstructing: value))
					}, completion: nil)
				}), during: bindingTarget.lifetime)
		}
	}


#endif
