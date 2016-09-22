import Foundation
import ReactiveSwift
import enum Result.NoError

extension NSObject {
	public func signal(for selector: Selector) -> Signal<(), NoError> {
		return .empty
	}
}
