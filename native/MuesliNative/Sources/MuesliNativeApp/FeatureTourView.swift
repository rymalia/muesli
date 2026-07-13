import SwiftUI

struct FeatureTourTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [FeatureTourTarget: CGRect] = [:]

    static func reduce(
        value: inout [FeatureTourTarget: CGRect],
        nextValue: () -> [FeatureTourTarget: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    @ViewBuilder
    func featureTourTarget(_ target: FeatureTourTarget?) -> some View {
        if let target {
            background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FeatureTourTargetPreferenceKey.self,
                        value: [
                            target: proxy.frame(in: .global)
                        ]
                    )
                }
            }
        } else {
            self
        }
    }
}

struct FeatureTourOverlay: View {
    let tour: FeatureTour
    let stepIndex: Int
    let spotlightRect: CGRect
    let containerSize: CGSize
    let onBack: () -> Void
    let onNext: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var step: FeatureTourStep {
        tour.steps[stepIndex]
    }

    private var expandedSpotlight: CGRect {
        spotlightRect.insetBy(dx: -8, dy: -8)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())

            FeatureTourDimmingShape(spotlight: expandedSpotlight, cornerRadius: 10)
                .fill(
                    Color.black.opacity(0.72),
                    style: FillStyle(eoFill: true, antialiased: true)
                )
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 10)
                .stroke(MuesliTheme.accent, lineWidth: 2)
                .frame(width: expandedSpotlight.width, height: expandedSpotlight.height)
                .position(x: expandedSpotlight.midX, y: expandedSpotlight.midY)
                .shadow(color: MuesliTheme.accent.opacity(0.55), radius: 10)
                .allowsHitTesting(false)

            callout
                .frame(width: 380)
                .position(calloutPosition)
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: step.id)
        .accessibilityElement(children: .contain)
    }

    private var callout: some View {
        VStack(alignment: .leading, spacing: MuesliTheme.spacing16) {
            HStack(alignment: .top, spacing: MuesliTheme.spacing12) {
                Image(systemName: step.systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(MuesliTheme.accent)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(step.eyebrow)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MuesliTheme.accent)
                    Text(step.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MuesliTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: MuesliTheme.spacing8)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MuesliTheme.textSecondary)
                .help("End walkthrough")
                .accessibilityLabel("End walkthrough")
            }

            Text(step.message)
                .font(MuesliTheme.body())
                .foregroundStyle(MuesliTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: MuesliTheme.spacing12) {
                Text("\(stepIndex + 1) of \(tour.steps.count)")
                    .font(MuesliTheme.caption())
                    .monospacedDigit()
                    .foregroundStyle(MuesliTheme.textTertiary)

                Spacer()

                if stepIndex > 0 {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: onNext) {
                    Label(
                        stepIndex == tour.steps.count - 1 ? "Done" : "Next",
                        systemImage: stepIndex == tour.steps.count - 1 ? "checkmark" : "chevron.right"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(MuesliTheme.spacing20)
        .background(MuesliTheme.backgroundRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(MuesliTheme.surfaceBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
    }

    private var calloutPosition: CGPoint {
        let calloutWidth: CGFloat = 380
        let calloutHeight: CGFloat = 230
        let margin: CGFloat = 20
        let gap: CGFloat = 24

        let proposedX: CGFloat
        let proposedY: CGFloat
        switch step.target {
        case .meetingsSidebar:
            proposedX = expandedSpotlight.maxX + gap + calloutWidth / 2
            proposedY = expandedSpotlight.midY
        case .insightsEntry, .liveCaptionsSetting:
            proposedX = expandedSpotlight.midX
            proposedY = expandedSpotlight.maxY + gap + calloutHeight / 2
        case .cloudCleanupSetting, .experimentalModels:
            proposedX = expandedSpotlight.midX
            proposedY = expandedSpotlight.minY - gap - calloutHeight / 2
        }

        return CGPoint(
            x: min(max(proposedX, margin + calloutWidth / 2), containerSize.width - margin - calloutWidth / 2),
            y: min(max(proposedY, margin + calloutHeight / 2), containerSize.height - margin - calloutHeight / 2)
        )
    }
}

struct FeatureTourInvitationView: View {
    let tour: FeatureTour
    let onAccept: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.66)
                .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: MuesliTheme.spacing20) {
                HStack(alignment: .top, spacing: MuesliTheme.spacing12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MuesliTheme.accent)
                        .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("MUESLI 0.8")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(MuesliTheme.accent)
                        Text("Want a quick tour of what’s new?")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(MuesliTheme.textPrimary)
                    }

                    Spacer(minLength: MuesliTheme.spacing8)

                    Button(action: onSkip) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MuesliTheme.textSecondary)
                    .help("Skip walkthrough")
                    .accessibilityLabel("Skip walkthrough")
                }

                Text("See \(tour.steps.count) additions in the places where you’ll actually use them. You can replay this later from What’s New in Muesli.")
                    .font(MuesliTheme.body())
                    .foregroundStyle(MuesliTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: MuesliTheme.spacing12) {
                    Spacer()
                    Button("Skip", action: onSkip)
                        .buttonStyle(.bordered)
                    Button(action: onAccept) {
                        Label("Take the Tour", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(MuesliTheme.spacing24)
            .frame(width: 460)
            .background(MuesliTheme.backgroundRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(MuesliTheme.surfaceBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 28, x: 0, y: 14)
        }
    }
}

private struct FeatureTourDimmingShape: Shape {
    let spotlight: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(
            in: spotlight,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return path
    }
}
