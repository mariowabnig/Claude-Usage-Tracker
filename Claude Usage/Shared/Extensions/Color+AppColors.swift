import SwiftUI
import AppKit

extension Color {
    /// Adaptive green with good contrast on both light and dark backgrounds.
    /// Light mode uses a darker forest green for readability on translucent/light surfaces.
    /// Dark mode uses a bright green close to the system default.
    static let adaptiveGreen = Color(nsColor: .adaptiveGreen)

    /// Amber color used during peak hours to signal "safe but expensive".
    static let peakAmber = Color(nsColor: .peakAmber)

    /// Returns adaptiveGreen during off-peak, peakAmber during peak hours.
    static var safeDynamic: Color {
        PeakHoursHelper.isPeakHours ? .peakAmber : .adaptiveGreen
    }
}

extension NSColor {
    /// Adaptive green with good contrast on both light and dark backgrounds.
    static let adaptiveGreen = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 60/255, green: 199/255, blue: 95/255, alpha: 1.0)
        } else {
            return NSColor(red: 27/255, green: 107/255, blue: 52/255, alpha: 1.0)
        }
    }

    /// Amber color for peak hours — warm yellow-orange that reads as "caution, not danger".
    static let peakAmber = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 255/255, green: 191/255, blue: 0/255, alpha: 1.0)  // bright amber
        } else {
            return NSColor(red: 204/255, green: 153/255, blue: 0/255, alpha: 1.0)  // darker amber
        }
    }

    /// Returns adaptiveGreen during off-peak, peakAmber during peak hours.
    static var safeDynamic: NSColor {
        PeakHoursHelper.isPeakHours ? .peakAmber : .adaptiveGreen
    }
}
