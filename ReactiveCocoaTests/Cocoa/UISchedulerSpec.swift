import Quick
import Nimble
import ReactiveSwift

class UISchedulerSpec: QuickSpec {
    override func spec() {
		describe("UIScheduler") {
			func dispatchSyncInBackground(action: () -> Void) {
				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), action)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
			}
			
			it("should run actions immediately when on the main thread") {
				let scheduler = UIScheduler()
				var values: [Int] = []
				expect(NSThread.isMainThread()) == true
				
				scheduler.schedule {
					values.append(0)
				}
				
				expect(values) == [ 0 ]
				
				scheduler.schedule {
					values.append(1)
				}
				
				scheduler.schedule {
					values.append(2)
				}
				
				expect(values) == [ 0, 1, 2 ]
			}
			
			it("should enqueue actions scheduled from the background") {
				let scheduler = UIScheduler()
				var values: [Int] = []
				
				dispatchSyncInBackground {
					scheduler.schedule {
						expect(NSThread.isMainThread()) == true
						values.append(0)
					}
					
					return
				}
				
				expect(values) == []
				expect(values).toEventually(equal([ 0 ]))
				
				dispatchSyncInBackground {
					scheduler.schedule {
						expect(NSThread.isMainThread()) == true
						values.append(1)
					}
					
					scheduler.schedule {
						expect(NSThread.isMainThread()) == true
						values.append(2)
					}
					
					return
				}
				
				expect(values) == [ 0 ]
				expect(values).toEventually(equal([ 0, 1, 2 ]))
			}
			
			it("should run actions enqueued from the main thread after those from the background") {
				let scheduler = UIScheduler()
				var values: [Int] = []
				
				dispatchSyncInBackground {
					scheduler.schedule {
						expect(NSThread.isMainThread()) == true
						values.append(0)
					}
					
					return
				}
				
				scheduler.schedule {
					expect(NSThread.isMainThread()) == true
					values.append(1)
				}
				
				scheduler.schedule {
					expect(NSThread.isMainThread()) == true
					values.append(2)
				}
				
				expect(values) == []
				expect(values).toEventually(equal([ 0, 1, 2 ]))
			}
		}
    }
}
