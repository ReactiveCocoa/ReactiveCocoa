//
//  NSURLSessionExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-03.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import swiftz_core

extension NSURLSession {
	/// Returns a Producer that will fetch data for each Consumer using the
	/// given request.
	func rac_dataProducerWithRequest(request: NSURLRequest) -> Producer<(NSData, NSURLResponse)> {
		return Producer { consumer in
			let task = self.dataTaskWithRequest(request) { (data, response, error) in
				if data == nil || response == nil {
					consumer.put(.Error(error))
				} else {
					let value = (data!, response!)
					consumer.put(.Next(Box(value)))
					consumer.put(.Completed)
				}
			}

			consumer.disposable.addDisposable {
				task.cancel()
			}

			task.resume()
		}
	}
}
