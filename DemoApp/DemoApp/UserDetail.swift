//
//  UserDetail.swift
//  DemoApp
//
//  Created by Phineas Guo on 2026/4/12.
//

import SwiftUI

struct UserDetail: View {
    var user: User
    var body: some View {
        ScrollView{
            VStack(alignment: .leading) {
                Text("User id: \(user.id ?? 0)")
                Text("User name: \(user.username ?? "")")
                Text("Name: \(user.name ?? "")")
                Text("Email: \(user.email ?? "")")
                Text("Home: \(user.address?.street ?? "")")
                Text("Work: \(user.company?.name ?? "")")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        
    }
}

#Preview {
    UserDetail(user:
        User(id: 0, name: "Phineas", username: "phineas", email: "email@example.com", address:
                Address(street: "W. Street", suite: "", city: "", zipcode: ""),
             company:
                Company(name: "XXX Inc.", catchPhrase: "Device", bs: "Device")
            )
    )
}
