import AVFoundation
import Combine
import LocalConsole
import SwiftUI

struct ExamplesView: View {
    private let medias: [Media] = [
        .init(
            title: "RTS1",
            url: URL(string: "https://lsvs-rts1-d.akamaized.net/out/v1/82ab0e39500a47a3b7ac54626d5399b5/index.m3u8?dw=7200")!
        ),
        .init(
            title: "SRF1",
            url: URL(string: "https://lsvs-srf1-d.akamaized.net/out/v1/759f0819be0649399fa116a78c524544/index.m3u8?dw=7200")!
        ),
        .init(
            title: "RSI1",
            url: URL(string: "https://lsvs-rsila1-d.akamaized.net/out/v1/8bb946314a8f4376bf4419dabb2dbd5d/index.m3u8?dw=7200")!
        ),
        .init(
            title: "Demain nous appartient (RTS)",
            url: URL(string: "https://rtsvod-drm-b.akamaized.net/out/v1/03018a5a71c345a1bdaffa55230fa35d/d25c9142a02b42eda81c1f4735f55700/0fe61b84421d48a298f572c80b135afb/index.m3u8?sdh=true")!
        ),
        .init(
            title: "Grey's Anatomy (SRF)",
            url: URL(string: "https://srfvod-drm-b.akamaized.net/out/v1/c7e77cdd66444a499b73f39ff5517793/ae13b06abd6d40d4b5ce39433d180ef2/518561e0b8f6482cba3c7f6701e48122/index.m3u8?caption=srf/6896e9fc-3b97-4971-a11e-6c009d518f65/episode/de/vod/vod.m3u8:de:Deutsch:sdh&webvttbaseurl=https://subtitles.eai-general.aws.srf.ch")!
        )
    ]

    @State private var selectedMedia: Media?

    var body: some View {
        List(medias, id: \.self) { media in
            Button {
                selectedMedia = media
            } label: {
                Text(media.title)
            }
        }
        .sheet(item: $selectedMedia) { media in
            PlayerView(media: media)
        }
        .safeAreaInset(edge: .bottom) {
            StatusView()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    LCManager.shared.isVisible.toggle()
                } label: {
                    Image(systemName: "apple.terminal")
                }
            }
        }
        .navigationTitle("Examples")
    }
}

#Preview {
    NavigationStack {
        ExamplesView()
    }
}

