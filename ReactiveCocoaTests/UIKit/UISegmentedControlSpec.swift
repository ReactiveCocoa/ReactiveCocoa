import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import Result

class UISegmentedControlSpec: QuickSpec {
	override func spec() {
		it("should accept changes from bindings to its selected segment index") {
			let s = UISegmentedControl(items: ["0", "1", "2"])
			s.selectedSegmentIndex = UISegmentedControl.noSegment
			expect(s.numberOfSegments) == 3

			let (pipeSignal, observer) = Signal<Int, NoError>.pipe()
			s.reactive.selectedSegmentIndex <~ SignalProducer(pipeSignal)

			expect(s.selectedSegmentIndex) == UISegmentedControl.noSegment

			observer.send(value: 1)
			expect(s.selectedSegmentIndex) == 1

			observer.send(value: 2)
			expect(s.selectedSegmentIndex) == 2
		}
	}
}
