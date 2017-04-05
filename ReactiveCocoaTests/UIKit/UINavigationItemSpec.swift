import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UINavigationItemSpec: QuickSpec {
	override func spec() {
		var navigationItem: UINavigationItem!
		weak var _navigationItem: UINavigationItem?
		
		beforeEach {
			navigationItem = UINavigationItem(title: "initial")
			_navigationItem = navigationItem
		}
		
		afterEach {
			navigationItem = nil
			expect(_navigationItem).to(beNil())
		}
		
		it("should accept changes from bindings to its title value") {
			let firstChange = "first"
			let secondChange = "second"
			
			navigationItem.title = ""
			
			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			navigationItem.reactive.title <~ pipeSignal
			
			observer.send(value: firstChange)
			expect(navigationItem.title) == firstChange
			
			observer.send(value: secondChange)
			expect(navigationItem.title) == secondChange
			
			observer.send(value: nil)
			expect(navigationItem.title).to(beNil())
		}
		
		#if os(iOS)
			it("should accept changes from bindings to its prompt value") {
				let firstChange = "first"
				let secondChange = "second"
				
				navigationItem.prompt = ""
				
				let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
				navigationItem.reactive.prompt <~ pipeSignal
				
				observer.send(value: firstChange)
				expect(navigationItem.prompt) == firstChange
				
				observer.send(value: secondChange)
				expect(navigationItem.prompt) == secondChange
				
				observer.send(value: nil)
				expect(navigationItem.prompt).to(beNil())
			}
		#endif
	}
}
