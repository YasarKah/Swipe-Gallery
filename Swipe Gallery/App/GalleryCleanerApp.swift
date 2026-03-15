//
//  GalleryCleanerApp.swift
//  Swipe Gallery
//
//  Uygulama giriş noktası. Ana ekran olarak HomeView gösterilir.
//

import SwiftUI

@main
struct GalleryCleanerApp: App {
    @StateObject private var preferences = AppPreferences()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(preferences)
                .environment(\.locale, Locale(identifier: preferences.language.localeIdentifier))
                .fontDesign(.rounded)
        }
    }
}

#Preview("App") {
    HomeView()
        .environmentObject(AppPreferences())
}
