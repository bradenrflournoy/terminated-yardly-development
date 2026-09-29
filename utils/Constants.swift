// Constants.swift
// Yardly

import Foundation
enum AppConfig {
    // Grace period before a job is considered late (seconds)
    static let latenessGraceSeconds: TimeInterval = 5 * 60

    // Hours before a booking when cancellation is locked
    static let cancellationLockHours: Int = 48
}

