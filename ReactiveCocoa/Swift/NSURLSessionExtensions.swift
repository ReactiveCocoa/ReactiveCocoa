//
//  NSURLSessionExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-03.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import LlamaKit

extension NSURLSession {
	/// Returns a signal that will fetch data using the given request.
	public func rac_dataWithRequest(request: NSURLRequest) -> ColdSignal<(NSData, NSURLResponse)> {
		return ColdSignal { subscriber in
			let task = self.dataTaskWithRequest(request) { (data, response, error) in
				if data == nil || response == nil {
					subscriber.put(.Error(error))
				} else {
					let value = (data!, response!)
					subscriber.put(.Next(Box(value)))
					subscriber.put(.Completed)
				}
			}

			subscriber.disposable.addDisposable {
				task.cancel()
			}

			task.resume()
		}
	}
}
