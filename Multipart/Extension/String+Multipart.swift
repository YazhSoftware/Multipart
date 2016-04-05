//
//  String+Multipart.swift
//  Multipart
//
//  Created by karuna on 4/5/16.
//  Copyright © 2016 Yazh. All rights reserved.
//

import Foundation

extension String {
  var ns: NSString {
    return self as NSString
  }
  // Get file type from string
  var pathExtension: String? {
    return ns.pathExtension
  }
  // Get file name from string
  var lastPathComponent: String? {
    return ns.lastPathComponent
  }
  
}