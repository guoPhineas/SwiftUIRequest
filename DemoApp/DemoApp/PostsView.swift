//
//  PostsView.swift
//  DemoApp
//
//  Created by Phineas Guo on 2026/4/12.
//

import SwiftUI
import SwiftUIRequest

struct PostsView: View {
    @Request(url: URL(string: "https://jsonplaceholder.typicode.com/posts")!) var posts: [Post]?
    
    var body: some View {
        NavigationStack{
            List(posts ?? []){post in
                PostView(post: post)
            }
            .toolbar {
                if $posts.isLoading {
                    ProgressView()
                } else {
                    Button("Reload", systemImage: "arrow.clockwise") {
                        _posts.reload()
                    }
                }
            }
            .navigationTitle("Posts")
        }
    }
}

#Preview {
    PostsView()
}

struct PostView: View {
    let post: Post
    var body: some View {
        VStack(alignment: .leading, spacing: 10){
            Text(post.title ?? "")
                .font(.title2)
                .bold()
            Text(post.body ?? "")
                .font(.title3)
        }
    }
}
