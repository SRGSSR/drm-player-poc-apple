import Foundation

struct DRMError: LocalizedError {
    static let missingContentKeyContext = Self(errorDescription: "The DRM license could not be retrieved")

    let errorDescription: String?
}
