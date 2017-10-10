import AppKit

#if swift(>=4.0)
internal typealias RACNSControlState = NSControl.StateValue
internal let RACNSOnState = NSControl.StateValue.on
internal let RACNSOffState = NSControl.StateValue.off
internal let RACNSMixedState = NSControl.StateValue.mixed
#else
internal typealias RACNSControlState = Int
internal let RACNSOnState = NSOnState
internal let RACNSOffState = NSOffState
internal let RACNSMixedState = NSMixedState
#endif
