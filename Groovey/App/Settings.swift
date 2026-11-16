import Foundation
import ServiceManagement
import SwiftUI

enum SourceFilter: String, CaseIterable, Identifiable {
    case any, spotify, appleMusic

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .any: return "Any App"
        case .spotify: return "Spotify Only"
        case .appleMusic: return "Apple Music Only"
        }
    }

    func accepts(bundleID: String) -> Bool {
        switch self {
        case .any: return true
        case .spotify: return bundleID == "com.spotify.client"
        case .appleMusic: return bundleID == "com.apple.Music"
        }
    }
}

final class Settings: ObservableObject {
    private let defaults: UserDefaults

    @Published var theme: Theme { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    @Published var source: SourceFilter { didSet { defaults.set(source.rawValue, forKey: "source") } }
    @Published var showOnDesktop: Bool { didSet { defaults.set(showOnDesktop, forKey: "showOnDesktop") } }
    @Published var hideWhenPaused: Bool { didSet { defaults.set(hideWhenPaused, forKey: "hideWhenPaused") } }
    @Published var showTrackInfo: Bool { didSet { defaults.set(showTrackInfo, forKey: "showTrackInfo") } }
    @Published private(set) var launchAtLogin: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["showOnDesktop": true, "hideWhenPaused": false, "showTrackInfo": true])
        theme = Theme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .warmRoom
        source = SourceFilter(rawValue: defaults.string(forKey: "source") ?? "") ?? .any
        showOnDesktop = defaults.bool(forKey: "showOnDesktop")
        hideWhenPaused = defaults.bool(forKey: "hideWhenPaused")
        showTrackInfo = defaults.bool(forKey: "showTrackInfo")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Groovey: could not change the login item: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
