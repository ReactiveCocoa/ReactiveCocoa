import ReactiveSwift
import enum Result.NoError
import AppKit

extension Reactive where Base: NSSlider {

	// Provided for cross-platform compatibility

	public var value: BindingTarget<Float> { return floatValue }
	public var values: Signal<Float, NoError> { return floatValues }
}
