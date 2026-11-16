import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var nowPlaying: NowPlayingService
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        if let track = nowPlaying.track {
            Text(track.artist.isEmpty ? track.title : "\(track.title) · \(track.artist)")
        } else {
            Text("Nothing Playing")
        }
        if nowPlaying.usingFallback {
            Text("Reading from Spotify and Music directly")
        }

        Divider()

        Picker("Scene", selection: $settings.theme) {
            ForEach(Theme.allCases) { theme in
                Text(theme.label).tag(theme)
            }
        }
        Picker("Music Source", selection: $settings.source) {
            ForEach(SourceFilter.allCases) { source in
                Text(source.label).tag(source)
            }
        }

        Divider()

        Toggle("Show on Desktop", isOn: $settings.showOnDesktop)
        Toggle("Hide When Paused", isOn: $settings.hideWhenPaused)
        Toggle("Show Song Title", isOn: $settings.showTrackInfo)

        Divider()

        Menu("Recently Played") {
            if history.entries.isEmpty {
                Text("No Songs Yet")
            } else {
                ForEach(history.entries.prefix(10)) { entry in
                    Text(entry.artist.isEmpty ? entry.title : "\(entry.title) · \(entry.artist)")
                }
                Divider()
                Button("Clear History") { history.clear() }
            }
        }

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
        ))
        Button("Check for Updates…") { AppModel.shared.checkForUpdates() }
        Button("About Groovey") { AppModel.shared.showAbout() }

        Divider()

        Button("Quit Groovey") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
