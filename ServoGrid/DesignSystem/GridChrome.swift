import SwiftUI
import UIKit

enum GridMotion {
    @MainActor
    static func valueChange() -> Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.22)
    }

    @MainActor
    static func sheet() -> Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : .snappy(duration: 0.28)
    }
}

enum GridHaptics {
    @MainActor
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor
    static func impact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct MapChrome<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            content
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 5))
        } else {
            content
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Rectangle())
                .overlay {
                    Rectangle()
                        .strokeBorder(GridPalette.hairline.opacity(0.85), lineWidth: 0.5)
                }
        }
    }
}

struct SolidPanel<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GridPalette.surface)
            .overlay {
                Rectangle()
                    .strokeBorder(GridPalette.hairline, lineWidth: 0.5)
            }
    }
}

struct TrustLabelView: View {
    let text: String
    var emphasizeDemo: Bool

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .default, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(emphasizeDemo ? GridPalette.amber : GridPalette.teal)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(AccessibilityID.trustLabel)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isStaticText)
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .default))
            .tracking(1.4)
            .foregroundStyle(GridPalette.muted)
    }
}

struct EvidenceRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundStyle(GridPalette.muted)
            Text(value)
                .font(.system(.body, design: .default))
                .foregroundStyle(GridPalette.ink)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct GridEmptyState: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.title3, design: .default, weight: .semibold))
            Text(message)
                .font(.system(.body, design: .default))
                .foregroundStyle(GridPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(GridButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}

struct GridButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .semibold))
            .foregroundStyle(prominent ? GridPalette.canvas : GridPalette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(prominent ? GridPalette.ink : GridPalette.surface)
            .overlay {
                Rectangle()
                    .strokeBorder(GridPalette.hairline, lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(GridPalette.hairline)
            .frame(height: 0.5)
    }
}

struct ScreenScaffold<Content: View>: View {
    let title: String
    let trustLabel: String
    let isDemo: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(.title2, design: .default, weight: .semibold))
                    .foregroundStyle(GridPalette.ink)
                Spacer(minLength: 12)
                TrustLabelView(text: trustLabel, emphasizeDemo: isDemo)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            Hairline()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(GridPalette.canvas)
    }
}
