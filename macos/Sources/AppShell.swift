import AppKit
import Foundation

// MARK: - DriveStageView

public final class DriveStageView: NSView {
    public let runtime: DirectorRuntime
    private var coverImage: NSImage?
    private var splashImage: NSImage?

    public init(frame frameRect: NSRect, runtime: DirectorRuntime) {
        self.runtime = runtime
        super.init(frame: frameRect)
        let coverURL = runtime.picsURL.appendingPathComponent("cover6.jpg")
        let splashURL = runtime.picsURL.appendingPathComponent("cdsplash.jpg")
        self.coverImage = NSImage(contentsOf: coverURL)
        self.splashImage = NSImage(contentsOf: splashURL)
        self.wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    public override func becomeFirstResponder() -> Bool {
        return true
    }

    public override var isOpaque: Bool {
        return true
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.setFill()
        bounds.fill()

        let activeImage = (runtime.currentMovie == .quit) ? (splashImage ?? coverImage) : coverImage
        if let img = activeImage, img.size.width > 0 && img.size.height > 0 {
            let viewW = bounds.width
            let viewH = bounds.height
            let imgW = img.size.width
            let imgH = img.size.height
            let scale = min(viewW / imgW, viewH / imgH)
            let drawW = imgW * scale
            let drawH = imgH * scale
            let drawRect = NSRect(
                x: (viewW - drawW) * 0.5,
                y: (viewH - drawH) * 0.5,
                width: drawW,
                height: drawH
            )
            img.draw(
                in: drawRect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }

        // Draw high-contrast telemetry overlay bar at the bottom for sighted / low-vision users
        let barHeight: CGFloat = 36.0
        let barRect = NSRect(x: 0, y: 0, width: bounds.width, height: barHeight)
        NSColor(calibratedWhite: 0.0, alpha: 0.78).setFill()
        barRect.fill()

        let statusText = runtime.accessibilityStatusDescription
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13.0, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.75, alpha: 1.0),
            .paragraphStyle: paragraph,
        ]
        let textRect = NSRect(x: 12, y: 8, width: max(0, bounds.width - 24), height: 20)
        (statusText as NSString).draw(in: textRect, withAttributes: attrs)
    }

    // MARK: Keyboard Input (Zero System Alert Beeps)

    public override func keyDown(with event: NSEvent) {
        let chars = event.charactersIgnoringModifiers ?? event.characters ?? ""
        runtime.handleKeyDown(keyCode: event.keyCode, characters: chars)
        needsDisplay = true
    }

    public override func keyUp(with event: NSEvent) {
        let chars = event.charactersIgnoringModifiers ?? event.characters ?? ""
        runtime.handleKeyUp(keyCode: event.keyCode, characters: chars)
        needsDisplay = true
    }

    public override func flagsChanged(with event: NSEvent) {
        // Consume modifier key changes cleanly without beeping
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Allow Command-key shortcuts (e.g. Cmd+Q, Cmd+W, Cmd+M, Cmd+H) to pass to the menu bar
        if event.modifierFlags.contains(.command) {
            return super.performKeyEquivalent(with: event)
        }
        // Intercept Return, Escape, Space, Arrow keys so AppKit never plays an alert beep
        if event.type == .keyDown {
            let chars = event.charactersIgnoringModifiers ?? event.characters ?? ""
            runtime.handleKeyDown(keyCode: event.keyCode, characters: chars)
            needsDisplay = true
            return true
        }
        return false
    }

    // MARK: NSAccessibility

    public override func isAccessibilityElement() -> Bool {
        return true
    }

    public override func accessibilityRole() -> NSAccessibility.Role? {
        return .group
    }

    public override func accessibilityLabel() -> String? {
        return "Drive Audio Game Stage"
    }

    public override func accessibilityValue() -> Any? {
        return runtime.accessibilityStatusDescription
    }
}

// MARK: - DriveWindow

public final class DriveWindow: NSWindow {
    public weak var stageView: DriveStageView?

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    public override func keyDown(with event: NSEvent) {
        if let stage = stageView {
            stage.keyDown(with: event)
        }
    }

    public override func keyUp(with event: NSEvent) {
        if let stage = stageView {
            stage.keyUp(with: event)
        }
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            return super.performKeyEquivalent(with: event)
        }
        if let stage = stageView {
            return stage.performKeyEquivalent(with: event)
        }
        return false
    }
}

// MARK: - DriveAppDelegate

public final class DriveAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public let runtime: DirectorRuntime
    public private(set) var window: DriveWindow?
    public private(set) var stageView: DriveStageView?
    private var tickTimer: Timer?
    private var lastTickTime: TimeInterval = 0

    public init(runtime: DirectorRuntime) {
        self.runtime = runtime
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let win = DriveWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        win.title = "Drive"
        win.minSize = NSSize(width: 640, height: 480)
        win.collectionBehavior = [.fullScreenPrimary]
        win.backgroundColor = .black
        win.delegate = self
        win.center()

        let stage = DriveStageView(frame: contentRect, runtime: runtime)
        stage.autoresizingMask = [.width, .height]
        win.contentView = stage
        win.stageView = stage
        win.makeFirstResponder(stage)
        win.makeKeyAndOrderFront(nil)

        NSApplication.shared.activate(ignoringOtherApps: true)

        self.window = win
        self.stageView = stage

        // Start real-time CoreAudio / AVAudioEngine output
        runtime.audioEngine.startHardwareAudioIfNeeded()

        // Start 60 Hz Director timer loop
        lastTickTime = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.onTimerTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.tickTimer = timer
    }

    private func onTimerTick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastTickTime
        lastTickTime = now

        let ticksToRun = max(1, min(6, Int((elapsed * 60.0).rounded())))
        for _ in 0..<ticksToRun {
            runtime.stepTick()
            if runtime.didQuit {
                tickTimer?.invalidate()
                tickTimer = nil
                runtime.audioEngine.stopHardwareAudio()
                NSApplication.shared.terminate(nil)
                return
            }
        }
        stageView?.needsDisplay = true
    }

    public func windowWillClose(_ notification: Notification) {
        tickTimer?.invalidate()
        tickTimer = nil
        runtime.audioEngine.stopHardwareAudio()
        NSApplication.shared.terminate(nil)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.invalidate()
        tickTimer = nil
        runtime.audioEngine.stopHardwareAudio()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit Drive",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        NSApplication.shared.mainMenu = mainMenu
    }
}
