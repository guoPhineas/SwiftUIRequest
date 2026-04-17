import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct URLMacro: ExpressionMacro {
    enum MacroError: Error {
        case cannotCreateMacro
    }
    
    public static func expansion<Node: FreestandingMacroExpansionSyntax, Context: MacroExpansionContext>(
        of node: Node,
        in context: Context
    ) throws -> ExprSyntax {
        let content = node.argumentList.first?.expression.as(StringLiteralExprSyntax.self)?.segments.first?.description ?? ""
        guard let _ = URL(string: content) else {
            throw MacroError.cannotCreateMacro
        }
        return "URL(string: \"\(raw: content)\")!"
    }
}
