//// The Swift Programming Language
//// https://docs.swift.org/swift-book
//

@freestanding(expression)
public macro URL(_ value: String) -> URL = #externalMacro(module: "Macros", type: "URLMacro")
