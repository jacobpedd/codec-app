//
//  CodecApp.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI
import Sentry


@main
struct CodecApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
#if DEBUG
        SentrySDK.start { options in
            options.dsn = "https://6b83b70f653851a2662bb1b9e74c0534@o4507612284059648.ingest.us.sentry.io/4507767057678336"
            options.tracesSampleRate = 0.1
            options.profilesSampleRate = 1.0
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .withAppEnvironment(coordinator)
        }
    }
}
