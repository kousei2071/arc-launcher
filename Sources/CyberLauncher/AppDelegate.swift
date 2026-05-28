import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var launcherWindow: CircularLauncherWindow?
    private var hotkeyService: HotkeyService?
    private var fileWatcher: ToggleFileWatcher?
    private var httpServer: ToggleHTTPServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let window = CircularLauncherWindow()
        self.launcherWindow = window
        setupStatusItem(window: window)

        fileWatcher = ToggleFileWatcher { [weak window] in window?.toggleVisibility() }
        httpServer = ToggleHTTPServer { [weak window] in window?.toggleVisibility() }
        hotkeyService = HotkeyService { [weak window] in window?.toggleVisibility() }
        hotkeyService?.start()

        printUsage()

        if ProcessInfo.processInfo.environment["CYBER_LAUNCHER_START_VISIBLE", default: "1"] == "1" {
            window.present()
        } else {
            window.dismiss()
        }
        print("  メニューバーアイコンからも開けます。")
    }

    private func setupStatusItem(window: CircularLauncherWindow) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.grid.cross", accessibilityDescription: "Cyber Launcher")
            ?? NSWorkspace.shared.icon(for: .application)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "ランチャーを表示", action: #selector(showFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "表示 / 非表示", action: #selector(toggleFromStatusItem), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        self.statusMenu = menu
        self.statusItem = statusItem
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp, let button = statusItem?.button, let menu = statusMenu {
            statusItem?.menu = menu
            button.performClick(nil)
            statusItem?.menu = nil
        } else {
            launcherWindow?.toggleVisibility()
        }
    }

    @objc private func toggleFromStatusItem() {
        launcherWindow?.toggleVisibility()
    }

    @objc private func showFromMenu() {
        launcherWindow?.present()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func printUsage() {
        print("Cyber Launcher 起動しました")
        print("  表示/非表示: ⌘ + Shift + L")
        print("  メニューバーアイコン … クリックでも表示")
        print("  マウスをアイコンへ動かしてクリックで起動")
        print("  Esc … 非表示 | Ctrl+C … 終了")
        if ProcessInfo.processInfo.environment["CYBER_LAUNCHER_NATIVE_GLASS", default: "1"] == "1", nativeGlassAvailable() {
            print("  背景: 壁紙ぼかし + フロストガラス（NSVisualEffectView）")
            if liquidGlassAvailable() {
                print("  Liquid Glass: CYBER_LAUNCHER_LIQUID=1 で有効化")
            }
        } else if nativeGlassAvailable() {
            print("  背景: 手描き（CYBER_LAUNCHER_NATIVE_GLASS=1 でネイティブ化）")
        } else {
            print("  背景: 手描き Liquid Glass 風")
        }
        print()
        print("  ※ ショートカットが効かない場合:")
        print("     ./scripts/install-macos-shortcut.sh を実行し")
        print("     システム設定 → キーボード → ショートカット → サービス で ⌘+Shift+L を設定")
        print()
    }
}
