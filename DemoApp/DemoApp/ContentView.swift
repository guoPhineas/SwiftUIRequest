//
//  ContentView.swift
//  DemoApp
//
//  Created by Phineas Guo on 2026/4/12.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView{
            Tab("Users", systemImage: "person.2") {
                UsersView()
            }
            Tab("Posts", systemImage: "newspaper") {
                PostsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
