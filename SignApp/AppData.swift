import Foundation

enum AppLinks {

    static let appURL = URL(string: "https://apps.apple.com/app/id6753080957")!

    static let termsOfUse = URL(
        string:
            "https://docs.google.com/document/d/e/2PACX-1vQb1WiVYSSlFTsXa8mUmH69cQIeZ7d5wwocTOl31Bk9bW84Az-9qN3qi7BALL5Tt6TQlCyc5Y3FvRkh/pub"
    )!
    static let privacyPolicy = URL(
        string:
            "https://docs.google.com/document/d/e/2PACX-1vQb1WiVYSSlFTsXa8mUmH69cQIeZ7d5wwocTOl31Bk9bW84Az-9qN3qi7BALL5Tt6TQlCyc5Y3FvRkh/pub"
    )!

    static var shareMessage: String {
        """
        Sign documents quickly and securely. Save time, sign anytime, anywhere. Download the app:
        \(appURL.absoluteString)
        """
    }

    static let weekly = "weeklysignpro"

    static var shareItems: [Any] { [shareMessage, appURL] }
}
