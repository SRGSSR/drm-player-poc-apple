import AVFoundation
import AVKit
import SwiftUI

struct PlayerView: View {
    let media: Media

    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear {
                let asset = AVURLAsset(url: media.url)
                ContentKeySessionManager.shared.addContentKeyRecipient(asset)
                player.replaceCurrentItem(with: .init(asset: asset))
                player.play()
            }
    }
}

#Preview {
    PlayerView(
        media: .init(
            title: "Bip Bop",
            url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
        )
    )
}
