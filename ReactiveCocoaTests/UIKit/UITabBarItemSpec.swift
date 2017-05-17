import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UITabBarSpec: QuickSpec {
	override func spec() {
		var tabBarItem: UITabBarItem!
		weak var _tabBarItem: UITabBarItem?
		
		beforeEach {
			tabBarItem = UITabBarItem(tabBarSystemItem: .downloads, tag: 1)
			_tabBarItem = tabBarItem
		}
		
		afterEach {
			tabBarItem = nil
			expect(_tabBarItem).to(beNil())
		}
		
		it("should accept changes from bindings to its badge value") {
			let firstChange = "first"
			let secondChange = "second"
			
			tabBarItem.badgeValue = ""
			
			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			tabBarItem.reactive.badgeValue <~ pipeSignal
			
			observer.send(value: firstChange)
			expect(tabBarItem.badgeValue) == firstChange
			
			observer.send(value: secondChange)
			expect(tabBarItem.badgeValue) == secondChange
			
			observer.send(value: nil)
			expect(tabBarItem.badgeValue).to(beNil())
		}
		
		if #available(iOS 10, *), #available(tvOS 10, *) {
			it("should accept changes from bindings to its badge color value") {
				let firstChange: UIColor = .red
				let secondChange: UIColor = .green
				
				tabBarItem.badgeColor = .blue
				
				let (pipeSignal, observer) = Signal<UIColor?, NoError>.pipe()
				tabBarItem.reactive.badgeColor <~ pipeSignal
				
				observer.send(value: firstChange)
				expect(tabBarItem.badgeColor) == firstChange
				
				observer.send(value: secondChange)
				expect(tabBarItem.badgeColor) == secondChange
				
				observer.send(value: nil)
				expect(tabBarItem.badgeColor).to(beNil())
			}
		}
	}
}
