import AVFoundation
import LocalConsole

final class ContentKeySessionManager: NSObject {
    static let shared = ContentKeySessionManager(
        certificateUrl: URL(string: "https://srg.live.ott.irdeto.com/licenseServer/streaming/v1/SRG/getcertificate?applicationId=live")!
    )

    private let certificateUrl: URL
    private let contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
    private let session = URLSession(configuration: .default)
    private let queue = DispatchQueue(label: "ch.defagos.drmplayer.session-manager")

    private init(certificateUrl: URL) {
        self.certificateUrl = certificateUrl
        super.init()
        contentKeySession.setDelegate(self, queue: queue)
    }
}

extension ContentKeySessionManager: AVContentKeySessionDelegate {
    private static func contentIdentifier(from keyRequest: AVContentKeyRequest) -> String? {
        guard let identifier = keyRequest.identifier as? String, let components = URLComponents(string: identifier) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "contentId" })?.value
    }

    private static func contentKeyContextRequest(from identifier: Any?, httpBody: Data) -> URLRequest? {
        guard let skdUrlString = identifier as? String,
              var components = URLComponents(string: skdUrlString) else {
            return nil
        }

        components.scheme = "https"
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = httpBody
        return request
    }

    func addContentKeyRecipient(_ recipient: AVContentKeyRecipient) {
        contentKeySession.addContentKeyRecipient(recipient)
    }

    private func appCertificate() async throws -> Data {
        try await session.data(from: certificateUrl).0
    }

    private func contentKeyRequest(keyRequest: AVContentKeyRequest, app: Data) async throws -> Data {
        guard let contentIdentifier = Self.contentIdentifier(from: keyRequest) else {
            throw DRMError.missingIdentifier
        }

        let data = try await keyRequest.makeStreamingContentKeyRequestData(forApp: app, contentIdentifier: Data(contentIdentifier.utf8))
        return data
    }

    private func contentKeyContext(keyRequest: AVContentKeyRequest, data: Data) async throws -> Data {
        guard let contentKeyContextRequest = Self.contentKeyContextRequest(
            from: keyRequest.identifier,
            httpBody: data
        ) else {
            throw DRMError.missingContentKeyContext
        }
        return try await session.data(for: contentKeyContextRequest).0
    }

    private func contentKeyContext(keyRequest: AVContentKeyRequest, isRenewing: Bool) async throws -> Data {
        await LCManager.shared.print("---------------------------")
        await LCManager.shared.print("Start for \(String(describing: keyRequest.identifier)), renewing = \(isRenewing)")
        let app = try await appCertificate()
        await LCManager.shared.print("Successfully retrieved app certificate")
        let data = try await contentKeyRequest(keyRequest: keyRequest, app: app)
        await LCManager.shared.print("Successfully generated SPC")
        let responseData = try await contentKeyContext(keyRequest: keyRequest, data: data)
        await LCManager.shared.print("Successfully retrieved CKC")
        return responseData
    }

    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        contentKeySession(session, process: keyRequest, isRenewing: false)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        contentKeySession(session, process: keyRequest, isRenewing: true)
    }

    func contentKeySession(_ session: AVContentKeySession, contentKeyRequestDidSucceed keyRequest: AVContentKeyRequest) {
        LCManager.shared.print("Content key request \(String(describing: keyRequest.identifier)) did succeed")
    }

    func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError err: any Error) {
        LCManager.shared.print("Content key request \(String(describing: keyRequest.identifier)) did fail with error \(err)")
    }

    private func contentKeySession(_ session: AVContentKeySession, process keyRequest: AVContentKeyRequest, isRenewing: Bool) {
        Task {
            do {
                let data = try await contentKeyContext(keyRequest: keyRequest, isRenewing: isRenewing)
                let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: data)
                keyRequest.processContentKeyResponse(response)
            }
            catch {
                await LCManager.shared.print("Failed with error \(error)")
                keyRequest.processContentKeyResponseError(error)
            }
        }
    }
}
