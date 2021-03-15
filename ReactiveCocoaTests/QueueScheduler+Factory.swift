import ReactiveSwift
import Foundation

extension QueueScheduler {
	static func makeForTesting(file: String = #file, line: UInt = #line) -> QueueScheduler {
		let file = URL(string: file)?.lastPathComponent ?? "<unknown>"
		let label = "reactiveswift:\(file):\(line)"

		if #available(OSX 10.10, iOS 8.0, *) {
			return QueueScheduler(name: label)
		} else {
			return QueueScheduler(name: label)
		}
	}
}
