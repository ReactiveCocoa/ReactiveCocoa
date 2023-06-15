import ReactiveSwift
import Foundation

extension QueueScheduler {
	static func makeForTesting(file: String = #file, line: UInt = #line) -> QueueScheduler {
		let file = URL(string: file)?.lastPathComponent ?? "<unknown>"
		let label = "reactiveswift:\(file):\(line)"
		return QueueScheduler(name: label)
	}
}
