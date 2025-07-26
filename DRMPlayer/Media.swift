import Foundation

struct Media: Hashable, Identifiable {
    let title: String
    let url: URL

    var id: String {
        title
    }
}
