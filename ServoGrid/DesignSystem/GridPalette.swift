import SwiftUI
import UIKit

enum GridPalette {
    static let canvas = dynamic(
        light: UIColor(red: 0.953, green: 0.937, blue: 0.902, alpha: 1),
        dark: UIColor(red: 0.043, green: 0.063, blue: 0.094, alpha: 1)
    )
    static let surface = dynamic(
        light: UIColor(red: 0.988, green: 0.980, blue: 0.961, alpha: 1),
        dark: UIColor(red: 0.078, green: 0.106, blue: 0.149, alpha: 1)
    )
    static let ink = dynamic(
        light: UIColor(red: 0.055, green: 0.102, blue: 0.169, alpha: 1),
        dark: UIColor(red: 0.902, green: 0.929, blue: 0.961, alpha: 1)
    )
    static let muted = dynamic(
        light: UIColor(red: 0.361, green: 0.420, blue: 0.478, alpha: 1),
        dark: UIColor(red: 0.541, green: 0.588, blue: 0.659, alpha: 1)
    )
    static let hairline = dynamic(
        light: UIColor(red: 0.851, green: 0.824, blue: 0.773, alpha: 1),
        dark: UIColor(red: 0.173, green: 0.208, blue: 0.267, alpha: 1)
    )
    static let teal = Color(red: 0.122, green: 0.722, blue: 0.659)
    static let amber = Color(red: 0.831, green: 0.627, blue: 0.090)
    static let coral = Color(red: 0.886, green: 0.357, blue: 0.290)
    static let steel = dynamic(
        light: UIColor(red: 0.275, green: 0.361, blue: 0.455, alpha: 1),
        dark: UIColor(red: 0.620, green: 0.698, blue: 0.780, alpha: 1)
    )

    static let markerFillLight = UIColor(red: 0.988, green: 0.980, blue: 0.961, alpha: 0.96)
    static let markerFillDark = UIColor(red: 0.078, green: 0.106, blue: 0.149, alpha: 0.96)
    static let markerInkLight = UIColor(red: 0.055, green: 0.102, blue: 0.169, alpha: 1)
    static let markerInkDark = UIColor(red: 0.902, green: 0.929, blue: 0.961, alpha: 1)

    static func band(_ band: RelativePriceBand) -> Color {
        switch band {
        case .low: teal
        case .typical: steel
        case .high: coral
        case .insufficientData: muted
        }
    }

    static func uiBand(_ band: RelativePriceBand) -> UIColor {
        UIColor(self.band(band))
    }

    static func freshness(_ state: FreshnessState) -> Color {
        switch state {
        case .fresh: teal
        case .ageing: amber
        case .stale: coral
        case .unknown: muted
        }
    }

    static func health(_ state: SourceHealthState) -> Color {
        switch state {
        case .operational, .demo: teal
        case .degraded: amber
        case .unavailable: coral
        }
    }

    static func severity(_ severity: MonitorSeverity) -> Color {
        switch severity {
        case .info: steel
        case .warning: amber
        case .critical: coral
        }
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
