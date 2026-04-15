//
//  User.swift
//  DemoApp
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation
import SwiftUIRequest

struct User: ResponseModel, Identifiable, Mockable {
    // Mock
    static let mockData: User = User(id: 0, name: "Bob", username: "bob", email: "bob@example.com", address: nil, company: nil)
    
    // Use ResponseModel protocol
    static let requestURL = URL(string: "https://jsonplaceholder.typicode.com/users/")!
    
    let id: Int?
    let name: String?
    let username: String?
    let email: String?
    let address: Address?
    let company: Company?
}
