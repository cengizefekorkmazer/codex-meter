//
//  StatusItemController.swift
//  CodexMeter
//

import Cocoa
import SwiftUI
import Combine

@MainActor
final class StatusItemController: NSObject {
    private let appState: AppState
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        setupPopover()
        setupSubscriptions()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: Constants.UI.popoverWidth,
                                 height: Constants.UI.popoverHeight)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(rootView: PopoverView(appState: appState))
        popover = pop
    }

    private func setupSubscriptions() {
        Publishers.CombineLatest(appState.$snapshots, appState.$settings)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.renderMenuBar() }
            .store(in: &cancellables)
        renderMenuBar()
    }

    // MARK: - Render

    private func renderMenuBar() {
        guard let button = statusItem?.button else { return }
        let primaryUsage = appState.primaryUsage

        switch appState.settings.displayMode {
        case .iconOnly:
            button.image = progressIcon(progress: primaryUsage / 100.0,
                                        color: ColorTheme.color(forUsage: primaryUsage))
            button.title = ""
            button.attributedTitle = NSAttributedString()
        case .compact:
            button.image = progressIcon(progress: primaryUsage / 100.0,
                                        color: ColorTheme.color(forUsage: primaryUsage))
            button.imagePosition = .imageLeading
            button.title = String(format: " %.0f%%", primaryUsage)
            button.attributedTitle = NSAttributedString()
        case .detailed:
            button.image = nil
            let snapshot = appState.snapshots.first
            let parts: [String] = [
                snapshot?.primary.map { "5h: \($0.usedPercent)%" } ?? "5h: —",
                snapshot?.secondary.map { "7d: \($0.usedPercent)%" } ?? "7d: —"
            ]
            let title = parts.joined(separator: " | ")
            let maxUsage = maxUsageAcross(snapshot)
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(ColorTheme.color(forUsage: maxUsage)),
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            ]
            button.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        }
    }

    private func maxUsageAcross(_ snapshot: RateLimitSnapshot?) -> Double {
        let candidates: [Double] = [
            snapshot?.primary.map { Double($0.usedPercent) } ?? 0,
            snapshot?.secondary.map { Double($0.usedPercent) } ?? 0
        ]
        return candidates.max() ?? 0
    }

    private func progressIcon(progress: Double, color: Color) -> NSImage {
        let size = NSSize(width: Constants.UI.menuBarIconSize, height: Constants.UI.menuBarIconSize)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.clear(rect)

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2 - 2
            let lineWidth: CGFloat = 2.5

            let bg = NSBezierPath()
            bg.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            NSColor.systemGray.withAlphaComponent(0.3).setStroke()
            bg.lineWidth = lineWidth
            bg.stroke()

            let clamped = min(max(progress, 0), 1)
            if clamped > 0 {
                let path = NSBezierPath()
                path.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - CGFloat(clamped) * 360,
                    clockwise: true
                )
                NSColor(color).setStroke()
                path.lineWidth = lineWidth
                path.lineCapStyle = .round
                path.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Popover toggle

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let statusItem,
              let popover,
              let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            removeEventMonitor()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            installEventMonitor()
        }
    }

    private func installEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let popover = self.popover, popover.isShown else { return }
            popover.performClose(nil)
            self.removeEventMonitor()
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
