//
//  TestError.swift
//  ReactiveCocoa
//
//  Created by Almas Sapargali on 1/26/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

enum TestError: Int {
	case Default = 0
	case Error1 = 1
	case Error2 = 2
}

extension TestError: ErrorType {
}
