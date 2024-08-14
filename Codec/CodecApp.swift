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
    init() {
        SentrySDK.start { options in
            options.dsn = "https://6b83b70f653851a2662bb1b9e74c0534@o4507612284059648.ingest.us.sentry.io/4507767057678336"

            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif
            
            // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
            // We recommend adjusting this value in production.
            options.tracesSampleRate = 1.0

            // Sample rate for profiling, applied on top of TracesSampleRate.
            // We recommend adjusting this value in production.
            options.profilesSampleRate = 1.0

            // Uncomment the following lines to add more data to your events
            // options.attachScreenshot = true // This adds a screenshot to the error events
            // options.attachViewHierarchy = true // This adds the view hierarchy to the error events
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(FeedModel())
        }
    }
}
