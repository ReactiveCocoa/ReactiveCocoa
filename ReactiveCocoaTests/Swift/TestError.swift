//
//  TestError.swift
//  ReactiveCocoa
//
//  Created by Almas Sapargali on 1/26/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

enum TestError: Int {
	case `default` = 0
	case error1 = 1
	case error2 = 2
}

extension TestError: ErrorProtocol {
}
