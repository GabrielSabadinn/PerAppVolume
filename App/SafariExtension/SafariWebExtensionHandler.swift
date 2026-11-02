import Foundation
import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private static let port = 47635

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any]
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: reply(to: message)]
        context.completeRequest(returningItems: [response])
    }

    private func reply(to message: [String: Any]?) -> [String: Any] {
        guard message?["type"] as? String == "config" else { return ["ok": true] }
        return ["port": SafariWebExtensionHandler.port, "token": Bundle.main.object(forInfoDictionaryKey: "PerAppVolumeToken") as? String ?? ""]
    }
}
