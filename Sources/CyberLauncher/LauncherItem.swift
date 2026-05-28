import AppKit
import Foundation

struct LauncherItem {
    let appName: String
    let icon: NSImage

    func open() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

func defaultItems() -> [LauncherItem] {
    [
        "Finder",
        "Dia",
        "Terminal",
        "Cursor",
        "Slack",
        "RunCat",
        "Google Chrome",
        "System Settings"
    ].map { LauncherItem(appName: $0, icon: loadMacAppIcon(appName: $0)) }
}

func macAppBundlePath(appName: String) -> String? {
    let script = #"POSIX path of (path to application "\#(appName)")"#
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    if (try? process.run()) != nil {
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines).trimmingSuffix("/")
            if path.hasSuffix(".app"), FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
    }

    let candidates = [
        "/Applications/\(appName).app",
        "/System/Applications/\(appName).app",
        "\(NSHomeDirectory())/Applications/\(appName).app"
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
}

func loadMacAppIcon(appName: String, size: CGFloat = 128) -> NSImage {
    if let path = macAppBundlePath(appName: appName) {
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = CGSize(width: size, height: size)
        return image
    }
    let fallback = NSWorkspace.shared.icon(for: .application)
    fallback.size = CGSize(width: size, height: size)
    return fallback
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
