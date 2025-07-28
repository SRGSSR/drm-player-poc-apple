import AVFoundation
import LocalConsole
import os

final class ContentKeySessionManager: NSObject {
    static let shared = ContentKeySessionManager(
        certificateUrl: URL(string: "https://srg.live.ott.irdeto.com/licenseServer/streaming/v1/SRG/getcertificate?applicationId=live")!
    )

    private let certificateUrl: URL
    private let contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
    private let session = URLSession(configuration: .default)
    private let queue = DispatchQueue(label: "ch.defagos.drmplayer.session-manager")
    private let logger = Logger(subsystem: "ch.defagos.drmplayer", category: "SessionManager")

    private init(certificateUrl: URL) {
        self.certificateUrl = certificateUrl
        super.init()
        contentKeySession.setDelegate(self, queue: queue)
    }
}

extension ContentKeySessionManager: AVContentKeySessionDelegate {
    private static func contentIdentifier(from keyRequest: AVContentKeyRequest) -> Data? {
        guard let identifier = keyRequest.identifier as? String,
              let components = URLComponents(string: identifier),
              let contentIdentifier = components.queryItems?.first(where: { $0.name == "contentId" })?.value else {
            return nil
        }
        return Data(contentIdentifier.utf8)
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
        try await keyRequest.makeStreamingContentKeyRequestData(forApp: app, contentIdentifier: Self.contentIdentifier(from: keyRequest))
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

    private func contentKeyContext(keyRequest: AVContentKeyRequest) async throws -> Data {
        let app = try await appCertificate()
        let data = try await contentKeyRequest(keyRequest: keyRequest, app: app)
        return try await contentKeyContext(keyRequest: keyRequest, data: data)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        LCManager.shared.print("Did provide key request \(String(describing: keyRequest.identifier))")
        logger.info("Did provide key request \(String(describing: keyRequest.identifier))")

        contentKeySession(session, process: keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        LCManager.shared.print("Did provide renewing key request \(String(describing: keyRequest.identifier))")
        logger.info("Did provide renewing key request \(String(describing: keyRequest.identifier))")

        contentKeySession(session, process: keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession, contentKeyRequestDidSucceed keyRequest: AVContentKeyRequest) {
        LCManager.shared.print("Content key request did succeeed")
        logger.info("Content key request did succeeed")
    }

    func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError err: any Error) {
        LCManager.shared.print("Content key request did fail with error \(err)")
        logger.info("Content key request did fail with error \(err)")
    }

    private func contentKeySession(_ session: AVContentKeySession, process keyRequest: AVContentKeyRequest) {
        Task {
            do {
                let data = try await contentKeyContext(keyRequest: keyRequest)
                let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: data)
                keyRequest.processContentKeyResponse(response)
            }
            catch {
                keyRequest.processContentKeyResponseError(error)
            }
        }
    }
}
