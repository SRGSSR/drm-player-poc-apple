import SwiftUI

struct StatusView: View {
    @StateObject private var model = StatusModel()

    var body: some View {
        VStack(alignment: .leading) {
            LabeledContent("App start", value: model.startDateString)
            LabeledContent("Media services lost", value: "\(model.mediaServicesLost)")
            LabeledContent("Media services reset", value: "\(model.mediaServicesReset)")
        }
        .padding()
    }
}
