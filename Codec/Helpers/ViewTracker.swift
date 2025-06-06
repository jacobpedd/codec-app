//
//  ViewTracker.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import Foundation
import Combine

class ViewTracker {
    private var timer: Timer?
    private var lastReportedProgress: Int = 0
    private var lastUpdateTime: Date = Date()
    private let interval: TimeInterval = 5
    private let minProgressChange: Int = 1
    private var currentClip: Clip?
    private var feedService: FeedService?
    private var cancellables = Set<AnyCancellable>()
    
    private var currentTime: Double = 0
    private var duration: Double = 1  // Default to 1 to avoid division by zero
    
    private var currentTimePublisher: Published<TimeInterval>.Publisher?
    private var durationPublisher: Published<Double>.Publisher?
    
    func setCurrentClip(_ clip: Clip?, currentTimePublisher: Published<TimeInterval>.Publisher, durationPublisher: Published<Double>.Publisher) {
        // If the clip has changed, submit a zero view for the new clip
        if let newClip = clip, newClip.id != currentClip?.id {
            submitZeroView(for: newClip)
        }
        
        currentClip = clip
        self.currentTimePublisher = currentTimePublisher
        self.durationPublisher = durationPublisher
        
        // Reset tracking-related variables
        lastReportedProgress = 0
        currentTime = 0
        duration = 1
    }
    
    func startTracking() {
        stopTracking() // Ensure we're not already tracking
        guard currentClip != nil else { return }
        
        lastUpdateTime = Date()
        
        // Subscribe to currentTime and duration publishers
        currentTimePublisher?
            .sink { [weak self] time in
                self?.currentTime = time
                self?.checkAndUpdateProgress()
            }
            .store(in: &cancellables)
        
        durationPublisher?
            .sink { [weak self] duration in
                self?.duration = max(duration, 1)  // Ensure duration is never zero
                self?.checkAndUpdateProgress()
            }
            .store(in: &cancellables)
        
        // Start the timer for periodic updates
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkAndUpdateProgress()
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
        updateProgress()
    }

    private func checkAndUpdateProgress() {
        let currentProgress = Int((currentTime / duration) * 100)
        let now = Date()
        
        if abs(currentProgress - lastReportedProgress) >= minProgressChange && now.timeIntervalSince(lastUpdateTime) >= interval {
            updateProgress()
            lastUpdateTime = now
        }
    }

    private func updateProgress() {
        guard let clip = currentClip else { return }
        let currentProgress = Int((currentTime / duration) * 100)
        
        if currentProgress != lastReportedProgress {
            lastReportedProgress = currentProgress
            Task {
                await feedService?.updateView(clipId: clip.id, duration: currentProgress)
            }
        }
    }

    func setFeedService(_ service: FeedService?) {
        self.feedService = service
    }
    
    private func submitZeroView(for clip: Clip) {
        Task {
            await feedService?.updateView(clipId: clip.id, duration: 0)
        }
    }
}
