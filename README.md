# SwiftUIRequest

SwiftUIRequest is a small Swift package for declarative network requests with SwiftUI-friendly state.

## What it provides

- `RequestModel` for describing a decodable API model with static request metadata
- `RequestPayload` and `RequestState` for inspecting decoded values, raw data, loading state, and errors
- `RequestConfiguration` for runtime headers, query items, and bearer authentication
- `RequestPreset` for reusing request configuration
- `@Request(...)` for loading a model or an array of models in SwiftUI
- `reload()` and `reloadAction` for triggering requests again

## `RequestModel`

A model type must conform to `RequestModel` and provide a base URL:

```swift
struct User: RequestModel {
    static let requestURL = URL(string: "https://api.example.com/users")!
    //static var requestMethod: HTTPMethod { .get  }
    //static var requestHeaders: [String: String] { [:] }

    let id: Int
    let name: String
    let username: String?
    let email: String?
}
```

`RequestModel` also supports these defaults:

- `requestMethod` defaults to `GET`
- `requestHeaders` defaults to an empty dictionary

If you use `@Request([User].self)`, the array automatically reuses the element type’s request metadata.

## `RequestConfiguration`

Use `RequestConfiguration` to append query items, add headers, or set a bearer token:

```swift
let configuration = RequestConfiguration(
    headers: ["X-App": "demo"],
    queryItems: [URLQueryItem(name: "include", value: "profile")],
    authenticationToken: "token"
)
```

The configuration can build a final URL with `url(from:)` and apply headers to a `URLRequest` with `apply(to:)`.

## `RequestPreset`

Use `RequestPreset` when you want to reuse the same configuration across multiple requests:

```swift
let preset = RequestPreset(configuration: configuration)
```

You can then combine it with a URL, method, and extra headers when making a request.

## SwiftUI usage

The `@Request` property wrapper loads data automatically and exposes the latest value as an optional `wrappedValue`.

```swift
import SwiftUI
import SwiftUIRequest

struct User: RequestModel, Identifiable {
    static let requestURL = URL(string: "https://api.example.com/users")!

    let id: Int?
    let name: String?
    let username: String?
    let email: String?
}

struct ContentView: View {
    @Request([User].self) private var users

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

There is an example app on [DemoApp folder](./DemoApp).

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

If you want decode failures to keep only the error, set `fallbackToRaw: false`.

```swift
@Request(
    [User].self,
    fallbackToRaw: false
) private var users
```

## Explicit URL requests

You can also create a request directly from a URL:

```swift
// Use RequestBaseModel protocol, only define the response model.
struct User: RequestBaseModel, Identifiable { 
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
// Use RequestBaseModel protocol, only define the response model.
struct User: RequestBaseModel, Identifiable { 
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
