import AVFoundation
import Combine
import Foundation

final class StatusModel: ObservableObject {
    private static let dateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    private let startDate = Date()

    @Published private(set) var mediaServicesLost = false
    @Published private(set) var mediaServicesReset = false

    var startDateString: String {
        Self.dateFormatter.string(from: startDate)
    }

    init() {
        mediaServicesLostPublisher()
            .assign(to: &$mediaServicesLost)
        mediaServicesResetPublisher()
            .assign(to: &$mediaServicesReset)
    }

    private func mediaServicesLostPublisher() -> AnyPublisher<Bool, Never> {
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereLostNotification)
            .map { _ in true }
            .prepend(false)
            .eraseToAnyPublisher()
    }

    private func mediaServicesResetPublisher() -> AnyPublisher<Bool, Never> {
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .map { _ in true }
            .prepend(false)
            .eraseToAnyPublisher()
    }
}

