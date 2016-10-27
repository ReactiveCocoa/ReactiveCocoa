import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import UIKit
import enum Result.NoError

class UIGestureRecognizerSpec: QuickSpec {
	override func spec() {
		var gestureRecognizer: TestTapGestureRecognizer!
		weak var _gestureRecognizer: TestTapGestureRecognizer?
		
		beforeEach {
			gestureRecognizer = TestTapGestureRecognizer()
			_gestureRecognizer = gestureRecognizer
		}
		
		afterEach {
			gestureRecognizer = nil
			expect(_gestureRecognizer).to(beNil())
		}
		
		it("should send a value when the gesture state changes") {
			let signal = gestureRecognizer.reactive.stateChanged
			
			var counter = 0
			signal.observeValues { _ in counter += 1 }
			
			expect(counter) == 0
			gestureRecognizer.fireGestureEvent(.possible)

			expect(counter) == 1
			
			gestureRecognizer.fireGestureEvent( .began)
			expect(counter) == 2
			
			gestureRecognizer.fireGestureEvent(.changed)
			expect(counter) == 3
			
			gestureRecognizer.fireGestureEvent(.ended)
			expect(counter) == 4

		}
	}
}

private struct TargetActionPair {
	let target: AnyObject
	let action: Selector
}

final private class TestTapGestureRecognizer: UITapGestureRecognizer {
	var targetActionPair: TargetActionPair?
	var forceState: UIGestureRecognizerState = .ended
	override var state: UIGestureRecognizerState {
		get { return forceState }
		set { self.state = newValue }
	}
	
	override func addTarget(_ target: Any, action: Selector) {
		targetActionPair = TargetActionPair(target: target as AnyObject, action: action)
	}
	
	func fireGestureEvent(_ state: UIGestureRecognizerState) {
		guard let targetAction = self.targetActionPair else { return }
		forceState = state
		_ = targetAction.target.perform(targetAction.action, with: self)
	}
}
