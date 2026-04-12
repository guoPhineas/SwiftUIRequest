//
//  ContentView.swift
//  DemoApp
//
//  Created by Phineas Guo on 2026/4/12.
//

import SwiftUI
import SwiftUIRequest

struct ContentView: View {
    @Request([User].self) private var users
    
    var body: some View {
        NavigationStack{
            VStack{
                if $users.isLoading {
                    ProgressView("Loading...")
                } else if let users = users {
                    List{
                        Section {
                            ForEach(users){user in
                                NavigationLink(user.name ?? "", destination: {
                                    UserDetail(user: user)
                                        .navigationTitle("User Detail")
                                        .navigationBarTitleDisplayMode( .inline)
                                })
                            }
                        }footer: {
                            VStack{
                                if let code = $users.responseCode {
                                    Text("HTTP \(code)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let error = $users.errorDescription {
                                    Text("Error: \(error)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }else{
                    VStack{
                        Text("Failed to load data.")
                        if let error = $users.errorDescription {
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                if $users.isLoading {
                    ProgressView()
                } else {
                    Button("Reload", systemImage: "arrow.clockwise") {
                        _users.reload()
                    }
                }
            }
            .navigationTitle("Users")
        }
    }
}

#Preview {
    ContentView()
}
