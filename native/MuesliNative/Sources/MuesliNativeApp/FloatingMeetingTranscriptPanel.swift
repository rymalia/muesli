import AppKit
import Observation
import SwiftUI

enum FloatingMeetingTranscriptPlacement {
    static let panelSize = NSSize(width: 360, height: 320)
    static let gap: CGFloat = 0
    static let screenInset: CGFloat = 8

    static func frame(
        beside indicatorFrame: NSRect,
        panelSize: NSSize = panelSize,
        visibleFrame: NSRect
    ) -> NSRect {
        let availableOnLeft = indicatorFrame.minX - visibleFrame.minX
        let availableOnRight = visibleFrame.maxX - indicatorFrame.maxX
        let prefersLeft = availableOnLeft >= panelSize.width + gap || availableOnLeft >= availableOnRight
        let proposedX = prefersLeft
            ? indicatorFrame.minX - gap - panelSize.width
            : indicatorFrame.maxX + gap
        let minX = visibleFrame.minX + screenInset
        let maxX = max(minX, visibleFrame.maxX - screenInset - panelSize.width)
        let minY = visibleFrame.minY + screenInset
        let maxY = max(minY, visibleFrame.maxY - screenInset - panelSize.height)
        return NSRect(
            x: min(max(proposedX, minX), maxX),
            y: min(max(indicatorFrame.midY - panelSize.height / 2, minY), maxY),
            width: panelSize.width,
            height: panelSize.height
        )
    }
}

enum FloatingMeetingTranscriptInteraction: Equatable {
    case dismiss
    case copy
    case openMeeting

    static func action(at point: NSPoint, in panelFrame: NSRect) -> Self? {
        guard panelFrame.contains(point) else { return nil }
        let headerMinY = panelFrame.maxY - 42
        guard point.y >= headerMinY else { return .openMeeting }

        if point.x >= panelFrame.maxX - 48 {
            return .copy
        }
        if point.x >= panelFrame.maxX - 88 {
            return .dismiss
        }
        return .openMeeting
    }
}

@MainActor
@Observable
final class FloatingMeetingTranscriptModel {
    let presentation = LiveTranscriptPresentationModel()
    var isPaused = false
    var isPresented = false

    func update(transcript: String, partialYou: String, partialOthers: String) {
        presentation.update(
            transcript: transcript,
            partialYou: partialYou,
            partialOthers: partialOthers
        )
    }

    func reset() {
        presentation.reset()
        isPaused = false
        isPresented = false
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

@MainActor
final class FloatingMeetingTranscriptPanelController {
    private let model = FloatingMeetingTranscriptModel()
    private let onHoverChanged: (Bool) -> Void
    private let onOpenNotes: () -> Void
    private let onDismiss: () -> Void
    private var hostingView: FirstMouseHostingView<FloatingMeetingTranscriptPanelView>?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    init(
        onHoverChanged: @escaping (Bool) -> Void,
        onOpenNotes: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onHoverChanged = onHoverChanged
        self.onOpenNotes = onOpenNotes
        self.onDismiss = onDismiss
    }

    var isVisible: Bool {
        hostingView?.superview != nil && hostingView?.isHidden == false
    }

    func update(transcript: String, partialYou: String, partialOthers: String) {
        model.update(
            transcript: transcript,
            partialYou: partialYou,
            partialOthers: partialOthers
        )
    }

    func setPaused(_ paused: Bool) {
        model.isPaused = paused
    }

    func show(in containerView: NSView, frame: NSRect) {
        let hostingView = hostingView ?? makeHostingView()
        if hostingView.superview !== containerView {
            hostingView.removeFromSuperview()
            containerView.addSubview(hostingView)
        }
        hostingView.frame = frame
        hostingView.isHidden = false
        model.isPresented = true
        startMouseMonitoring()
    }

    func hide() {
        stopMouseMonitoring()
        model.isPresented = false
        hostingView?.isHidden = true
        hostingView?.removeFromSuperview()
    }

    func reset() {
        hide()
        model.reset()
    }

    func close() {
        stopMouseMonitoring()
        model.isPresented = false
        hostingView?.removeFromSuperview()
        hostingView = nil
    }

    func containsMouseLocation() -> Bool {
        screenFrame?.contains(NSEvent.mouseLocation) == true
    }

    private var screenFrame: NSRect? {
        guard isVisible, let hostingView, let window = hostingView.window else { return nil }
        let frameInWindow = hostingView.convert(hostingView.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }

    private func startMouseMonitoring() {
        guard localMouseMonitor == nil, globalMouseMonitor == nil else { return }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let location = NSEvent.mouseLocation
            let handled = MainActor.assumeIsolated {
                self?.routeClick(at: location) ?? false
            }
            return handled ? nil : event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                _ = self?.routeClick(at: location)
            }
        }
    }

    private func stopMouseMonitoring() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    @discardableResult
    private func routeClick(at screenPoint: NSPoint) -> Bool {
        guard let screenFrame,
              let interaction = FloatingMeetingTranscriptInteraction.action(
                at: screenPoint,
                in: screenFrame
              ) else { return false }

        switch interaction {
        case .dismiss:
            onDismiss()
        case .copy:
            copyTranscript()
        case .openMeeting:
            onOpenNotes()
        }
        return true
    }

    private func copyTranscript() {
        let text = LiveTranscriptCopyContent.text(
            transcript: model.presentation.transcript,
            partialYou: model.presentation.partialYou,
            partialOthers: model.presentation.partialOthers
        )
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func makeHostingView() -> FirstMouseHostingView<FloatingMeetingTranscriptPanelView> {
        let hostingView = FirstMouseHostingView(
            rootView: FloatingMeetingTranscriptPanelView(
                model: model,
                onHoverChanged: onHoverChanged,
                onOpenNotes: onOpenNotes,
                onDismiss: onDismiss
            )
        )
        hostingView.wantsLayer = true
        return hostingView
    }
}

private struct FloatingMeetingTranscriptPanelView: View {
    let model: FloatingMeetingTranscriptModel
    let onHoverChanged: (Bool) -> Void
    let onOpenNotes: () -> Void
    let onDismiss: () -> Void
    @State private var didCopy = false

    private var partialYou: String {
        model.presentation.partialYou.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var partialOthers: String {
        model.presentation.partialOthers.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var messages: [TranscriptChatMessage] {
        model.presentation.messages
    }

    private var copyText: String {
        LiveTranscriptCopyContent.text(
            transcript: model.presentation.transcript,
            partialYou: model.presentation.partialYou,
            partialOthers: model.presentation.partialOthers
        )
    }

    var body: some View {
        if model.isPresented {
            VStack(spacing: 0) {
                header
                Divider().background(MuesliTheme.surfaceBorder)
                transcript
            }
            .frame(
                width: FloatingMeetingTranscriptPlacement.panelSize.width,
                height: FloatingMeetingTranscriptPlacement.panelSize.height
            )
            .background(.ultraThinMaterial)
            .background(MuesliTheme.backgroundRaised.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(MuesliTheme.surfaceBorder, lineWidth: 1)
            }
            .onHover(perform: onHoverChanged)
        }
    }

    private var header: some View {
        HStack(spacing: MuesliTheme.spacing8) {
            Text("Live transcript")
                .font(MuesliTheme.callout().weight(.semibold))
                .foregroundStyle(MuesliTheme.textPrimary)
            Spacer()
            Circle()
                .fill(model.isPaused ? MuesliTheme.textTertiary : MuesliTheme.success)
                .frame(width: 6, height: 6)
            Text(model.isPaused ? "Paused" : "Live")
                .font(MuesliTheme.caption())
                .foregroundStyle(MuesliTheme.textSecondary)
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MuesliTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Hide live transcript")
            Button(action: copyTranscript) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(didCopy ? MuesliTheme.success : MuesliTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(copyText.isEmpty)
            .help("Copy transcript")
        }
        .padding(.horizontal, MuesliTheme.spacing16)
        .frame(height: 42)
    }

    private var transcript: some View {
        ScrollView {
            LiveTranscriptFeedView(
                messages: messages,
                partialYou: partialYou,
                partialOthers: partialOthers,
                horizontalPadding: MuesliTheme.spacing12,
                topPadding: MuesliTheme.spacing8,
                bottomPadding: MuesliTheme.spacing8,
                onOpen: onOpenNotes
            )
        }
        .defaultScrollAnchor(.bottom)
    }

    private func copyTranscript() {
        guard !copyText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copyText, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didCopy = false
        }
    }

}
