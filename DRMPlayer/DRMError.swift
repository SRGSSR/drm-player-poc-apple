import Foundation

struct DRMError: LocalizedError {
    static let missingIdentifier = Self(errorDescription: "The content identifier could not be retrieved")
    static let missingContentKeyContext = Self(errorDescription: "The DRM license could not be retrieved")

    let errorDescription: String?
}
