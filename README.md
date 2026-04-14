# SwiftUIRequest

SwiftUIRequest is a small Swift package for declarative network requests with SwiftUI-friendly state.

## Getting Started

Add SwiftUIRequest in your Swift Package Manager.

```swift
.package(url: "https://github.com/guoPhineas/SwiftUIRequest.git", branch: "main"),
```

Import in your code.

```swift
import SwiftUIRequest
```

## Usage

The `@Request` property wrapper loads data automatically and exposes the latest value as an optional `wrappedValue`.

> There is an example app on [DemoApp folder](./DemoApp).

```swift
import SwiftUI
import SwiftUIRequest

struct User: ResponseModel, Identifiable {
    static let requestURL = URL(string: "https://api.example.com/users")!
    // Default request attrbutes
    //static var requestMethod = .get
    //static var requestHeaders = [:]
    //static var requestBody = nil

    let id: Int?
    let name: String?
    let username: String?
    let email: String?
}

struct ContentView: View {
    @Request([User].self) private var users // The default request method is GET

    var body: some View {
        VStack(spacing: 12) {
            if $users.isLoading {
                ProgressView("Loading...")
            } else {
                List(users ?? []) { user in
                    Text(user.name ?? "")
                }
            }

            Button("Reload") {
                _users.reload()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

Or

```swift
// Use ResponseBaseModel protocol, only define the response model.
struct User: ResponseBaseModel, Identifiable { 
    let id: Int?
    let name: String?
    let username: String?
    let email: String?
}

// Use in SwiftUI view
@Request(
    url: URL(string: "https://api.example.com/users")!,
    method: .get,
    headers: ["Accept": "application/json"]
) private var users: [User]?
```

## Explicit URL requests

You can also create a request directly from a URL:

```swift
// Use ResponseBaseModel protocol, only define the response model.
struct User: ResponseBaseModel, Identifiable { 
    let id: Int?
    let name: String?
    let username: String?
    let email: String?
}

// Use in SwiftUI view
@Request(
    url: URL(string: "https://api.example.com/users")!,
    method: .get,
    headers: ["Accept": "application/json"]
) private var users: [User]?
```

Or reuse a preset with an explicit URL:

```swift
// Use ResponseBaseModel protocol, only define the response model.
struct User: ResponseBaseModel, Identifiable { 
    let id: Int?
    let name: String?
    let username: String?
    let email: String?
}

// Use in SwiftUI view
@Request(
    preset: preset,
    url: URL(string: "https://api.example.com/users")!,
    method: .get
) private var users: [User]?
```

## Mock

You can set mock data and it will be returned automatically when you are debuging your app.

```swift
struct User: ResponseBaseModel, Identifiable, Mockable {
    static var mockData: any ResponseBaseModel  {
        User(id: 0, name: "Bob", username: "bob", email: "bob@example.com", address: nil, company: nil)
    }
    
    let id: Int?
    let name: String?
    let username: String?
    let email: String?
    let address: Address?
    let company: Company?
}
```

Just make your model to confirm to `Mockable` protocol and set the mockData.

## RequestConfiguration

Use `RequestConfiguration` to append query items, add headers, or set a bearer token:

```swift
@Request([User].self, configuration: .init(
    headers: ["X-App": "demo"],
    queryItems: [URLQueryItem(name: "include", value: "profile")],
    authenticationToken: "token"
)) private var users
```

## Request state

The projected value exposes the observable request store:

- `$users.isLoading` indicates whether a request is running
- `$users.responseCode` exposes the HTTP status code when available
- `$users.errorDescription` exposes the latest error message
- `$users.value` returns the decoded value when payload is `.decoded`
- `$users.rawData` returns raw bytes when payload is `.raw`

The wrapper itself also exposes convenience properties:

- `users` through `wrappedValue`
- `$users` through `projectedValue`
- `responseCode`
- `isLoading`
- `errorDescription`
- `rawData`
- `reloadAction`
- `reload()`

## Decoding fallback

By default, if decoding fails, the request stores raw response data in `RequestState.payload` as `.raw(data)` and records the decoding error in `errorDescription`.

If you want decode failures to keep the raw data, set `fallbackToRaw: false`.

```swift
@Request(
    [User].self,
    fallbackToRaw: false
) private var users
```

## Supported HTTP methods

`HTTPMethod` includes:

- `get`
- `post`
- `put`
- `patch`
- `delete`
- `head`
- `options`
- `trace`
- `connect`

## Notes

- The request starts automatically when the wrapper is created.
- The latest response status code is available from `RequestState.responseCode`.
- `RequestStore` is `@Observable`, so SwiftUI views can react to changes in loading and result state.
