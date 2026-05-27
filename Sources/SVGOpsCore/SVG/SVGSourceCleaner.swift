import Foundation

struct SVGSourceCleaner {
    func clean(_ svg: String) -> String {
        var output = svg
        output = output.replacingOccurrences(of: #"(?is)<\?xml\b.*?\?>"#, with: "", options: .regularExpression)
        output = output.replacingOccurrences(of: #"(?is)<!DOCTYPE\s+svg\b.*?>"#, with: "", options: .regularExpression)
        output = output.replacingOccurrences(of: #"(?s)<!--.*?-->"#, with: "", options: .regularExpression)
        output = output.replacingOccurrences(of: #"(?s)<metadata\b.*?</metadata>"#, with: "", options: .regularExpression)
        return output
    }
}
