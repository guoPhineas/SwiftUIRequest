import Foundation
import Testing
@testable import SwiftUIRequest

struct User: RequestModel, Sendable, Equatable {
    static let requestURL = URL(string: "https://example.com/user")!
    var id: Int?
    var name: String?

    static var requestHeaders: [String : String] {
        ["Accept": "application/json"]
    }
}

@Suite("Request framework")
struct SwiftUIRequestTests {
    @Test func configurationBuildsURLAndHeaders() {
        let config = RequestConfiguration(headers: ["X-Test": "1"], queryItems: [URLQueryItem(name: "page", value: "2")], authenticationToken: "abc")
        let preset = RequestPreset(configuration: config)
        let request = preset.makeRequest(for: URL(string: "https://example.com/api")!, method: .post)
        #expect(request?.httpMethod == "POST")
        #expect(request?.value(forHTTPHeaderField: "X-Test") == "1")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
        #expect(request?.url?.absoluteString.contains("page=2") == true)
    }

    @Test func requestModelDefaultsAreAvailable() {
        #expect(User.requestMethod == .get)
        #expect(User.requestHeaders["Accept"] == "application/json")
    }
}
