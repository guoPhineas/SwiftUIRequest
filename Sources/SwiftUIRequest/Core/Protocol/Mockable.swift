//
//  File.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/14.
//

import Foundation

/// A protocol that confirming model mockable
public protocol Mockable where Self: ResponseBaseModel{
    /// Mock data
    static var mockData: ResponseBaseModel { get }
}
