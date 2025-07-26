import AVFoundation
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

    private func appCertificate(completion: @escaping (Result<Data, Error>) -> Void) {
        session.dataTask(with: certificateUrl) { data, _, error in
            if let error {
                completion(.failure(error))
            }
            else if let data {
                completion(.success(data))
            }
        }.resume()
    }

    private func contentKeyRequest(keyRequest: AVContentKeyRequest, app: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        keyRequest.makeStreamingContentKeyRequestData(forApp: app, contentIdentifier: Self.contentIdentifier(from: keyRequest)) { data, error in
            if let error {
                completion(.failure(error))
            }
            else if let data {
                completion(.success(data))
            }
        }
    }

    private func contentKeyContext(keyRequest: AVContentKeyRequest, data: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let contentKeyContextRequest = Self.contentKeyContextRequest(
            from: keyRequest.identifier,
            httpBody: data
        ) else {
            completion(.failure(DRMError.missingContentKeyContext))
            return
        }
        session.data(with: contentKeyContextRequest, completion: completion)
            .resume()
    }

    private func contentKeyContext(keyRequest: AVContentKeyRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        appCertificate { result in
            switch result {
            case let .success(app):
                self.contentKeyRequest(keyRequest: keyRequest, app: app) { result in
                    switch result {
                    case let .success(data):
                        self.contentKeyContext(keyRequest: keyRequest, data: data, completion: completion)
                    case .failure:
                        completion(result)
                    }
                }
            case .failure:
                completion(result)
            }
        }
    }

    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        contentKeySession(session, process: keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        contentKeySession(session, process: keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession, contentKeyRequestDidSucceed keyRequest: AVContentKeyRequest) {
        logger.info("Content key request did succeeed")
    }

    func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError err: any Error) {
        logger.info("Content key request did fail with error \(err)")
    }

    private func contentKeySession(_ session: AVContentKeySession, process keyRequest: AVContentKeyRequest) {
        contentKeyContext(keyRequest: keyRequest) { result in
            self.queue.async {
                switch result {
                case let .success(data):
                    let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: data)
                    keyRequest.processContentKeyResponse(response)
                case let .failure(error):
                    keyRequest.processContentKeyResponseError(error)
                }
            }
        }
    }
}
