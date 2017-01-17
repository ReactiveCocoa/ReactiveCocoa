import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UILabel {
	/// Sets the text of the label.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.text = $1 }
	}

	/// Sets the attributed text of the label.
	public var attributedText: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.attributedText = $1 }
	}

	/// Sets the color of the text of the label.
	public var textColor: BindingTarget<UIColor> {
		return makeBindingTarget { $0.textColor = $1 }
	}
}

extension UILabel {
	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UILabel,
		source: Source
	) -> Disposable? where Source.Value == String?, Source.Error == NoError {
		return target.reactive.text <~ source
	}

	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UILabel,
		source: Source
	) -> Disposable? where Source.Value == String, Source.Error == NoError {
		return target.reactive.text <~ source
	}

	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UILabel,
		source: Source
	) -> Disposable? where Source.Value == NSAttributedString?, Source.Error == NoError {
		return target.reactive.attributedText <~ source
	}

	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UILabel,
		source: Source
	) -> Disposable? where Source.Value == NSAttributedString, Source.Error == NoError {
		return target.reactive.attributedText <~ source
	}
}
