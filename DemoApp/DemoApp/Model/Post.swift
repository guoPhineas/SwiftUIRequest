//
//  Post.swift
//  DemoApp
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation
import SwiftUIRequest

struct Post: ResponseBaseModel, Identifiable { // Use ResponseBaseModel protocol
    let userId: Int?
    let id: Int?
    let title: String?
    let body: String?
}
