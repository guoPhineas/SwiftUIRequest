//
//  Address.swift
//  DemoApp
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation
import SwiftUIRequest

struct Address: ResponseBaseModel {
    let street: String?
    let suite: String?
    let city: String?
    let zipcode: String?
}
