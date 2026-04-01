//
//  ProviderHistory.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation

// MARK: - Provider History Series Kind

/// Identifies the type of historical data series for charting
enum ProviderHistorySeriesKind: String, Codable, CaseIterable {
    case session            // Short-term session (e.g. Claude 5-hour)
    case weekly             // Weekly usage cycle
    case monthly            // Monthly usage cycle
    case billing            // API billing cycle
    case premiumRequests    // Copilot premium requests
    case chatRequests       // Copilot chat requests
    case experimental       // Experimental/unstable data

    var displayName: String {
        switch self {
        case .session:          return "history.chart.session_usage".localized
        case .weekly:           return "history.chart.weekly_usage".localized
        case .monthly:          return "Monthly Usage"
        case .billing:          return "history.chart.api_billing".localized
        case .premiumRequests:  return "Premium Requests"
        case .chatRequests:     return "Chat Requests"
        case .experimental:     return "Experimental"
        }
    }
}

// MARK: - History Value Unit

/// Unit for history values, allowing different providers to express metrics differently
enum HistoryValueUnit: String, Codable {
    case percentage     // 0-100 percentage
    case tokens         // Raw token count
    case requests       // Request count
    case cents          // Currency in cents
    case dollars        // Currency in dollars
    case count          // Generic count
}

// MARK: - Provider History Point

/// A single data point in a provider's usage history
struct ProviderHistoryPoint: Codable, Identifiable, Equatable {
    let id: UUID
    let provider: UsageProviderKind
    let series: ProviderHistorySeriesKind
    let timestamp: Date
    let value: Double
    let unit: HistoryValueUnit
    let resetTime: Date?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        provider: UsageProviderKind,
        series: ProviderHistorySeriesKind,
        timestamp: Date,
        value: Double,
        unit: HistoryValueUnit = .percentage,
        resetTime: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.provider = provider
        self.series = series
        self.timestamp = timestamp
        self.value = value
        self.unit = unit
        self.resetTime = resetTime
        self.metadata = metadata
    }
}

// MARK: - Provider History Series

/// A named series of historical data points for charting
struct ProviderHistorySeries: Identifiable, Equatable {
    let id: String
    let provider: UsageProviderKind
    let kind: ProviderHistorySeriesKind
    let displayName: String
    let unit: HistoryValueUnit
    let points: [ProviderHistoryPoint]

    /// Whether this series has any data
    var isEmpty: Bool { points.isEmpty }

    /// Points sorted chronologically (oldest first)
    var sortedPoints: [ProviderHistoryPoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Provider History Data

/// Container for a profile's provider-neutral usage history
struct ProviderHistoryData: Codable, Equatable {
    var points: [ProviderHistoryPoint]

    init(points: [ProviderHistoryPoint] = []) {
        self.points = points
    }

    /// Filter points by provider
    func points(for provider: UsageProviderKind) -> [ProviderHistoryPoint] {
        points.filter { $0.provider == provider }
    }

    /// Filter points by series kind
    func points(for series: ProviderHistorySeriesKind) -> [ProviderHistoryPoint] {
        points.filter { $0.series == series }
    }

    /// Filter points by provider and series
    func points(for provider: UsageProviderKind, series: ProviderHistorySeriesKind) -> [ProviderHistoryPoint] {
        points.filter { $0.provider == provider && $0.series == series }
    }

    /// Build chart-ready series from stored points
    func series(for provider: UsageProviderKind) -> [ProviderHistorySeries] {
        let providerPoints = points(for: provider)
        let grouped = Dictionary(grouping: providerPoints) { $0.series }

        return grouped.map { kind, pts in
            ProviderHistorySeries(
                id: "\(provider.rawValue)-\(kind.rawValue)",
                provider: provider,
                kind: kind,
                displayName: kind.displayName,
                unit: pts.first?.unit ?? .percentage,
                points: pts
            )
        }.sorted { $0.kind.rawValue < $1.kind.rawValue }
    }

    mutating func addPoint(_ point: ProviderHistoryPoint) {
        points.append(point)
    }

    var count: Int { points.count }
    var isEmpty: Bool { points.isEmpty }
}

// MARK: - Claude History Adapter

/// Converts existing Claude UsageSnapshots to the provider-neutral history format
enum ClaudeHistoryAdapter {

    /// Convert a Claude UsageSnapshot into provider-neutral history points
    static func historyPoints(from snapshot: UsageSnapshot) -> [ProviderHistoryPoint] {
        var points: [ProviderHistoryPoint] = []

        switch snapshot.resetType {
        case .sessionReset:
            if let pct = snapshot.sessionPercentage {
                points.append(ProviderHistoryPoint(
                    provider: .claude,
                    series: .session,
                    timestamp: snapshot.timestamp,
                    value: pct,
                    unit: .percentage,
                    resetTime: snapshot.triggeringResetTime
                ))
            }

        case .weeklyReset:
            if let pct = snapshot.weeklyPercentage {
                points.append(ProviderHistoryPoint(
                    provider: .claude,
                    series: .weekly,
                    timestamp: snapshot.timestamp,
                    value: pct,
                    unit: .percentage,
                    resetTime: snapshot.triggeringResetTime
                ))
            }

        case .billingCycle:
            if let cents = snapshot.apiSpendCents {
                points.append(ProviderHistoryPoint(
                    provider: .claude,
                    series: .billing,
                    timestamp: snapshot.timestamp,
                    value: Double(cents),
                    unit: .cents,
                    resetTime: snapshot.triggeringResetTime,
                    metadata: ["currency": snapshot.apiCurrency ?? "USD"]
                ))
            }
        }

        return points
    }

    /// Convert an array of Claude UsageSnapshots to ProviderHistorySeries for charting
    static func series(from snapshots: [UsageSnapshot]) -> [ProviderHistorySeries] {
        let allPoints = snapshots.flatMap { historyPoints(from: $0) }
        let data = ProviderHistoryData(points: allPoints)
        return data.series(for: .claude)
    }
}
