//
//  SanityAppApp.swift
//  SanityApp
//
//  Created by Friederike Quint on 28.12.25.
//

import SwiftUI

enum AppConfig {
    static let supportedYears: ClosedRange<Int> = 2026...2030
    static let dailyQuestion: String = "How has your day been? Log your daily mood"
}

@main
struct SanityAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
