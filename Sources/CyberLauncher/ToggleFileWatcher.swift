import Foundation

final class ToggleFileWatcher: @unchecked Sendable {
    private let toggle: () -> Void
    private let toggleDirectory: URL
    private let toggleFile: URL
    private var descriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private var isResetting = false

    init(toggle: @escaping () -> Void) {
        self.toggle = toggle
        self.toggleDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CyberLauncher", isDirectory: true)
        self.toggleFile = toggleDirectory.appendingPathComponent("toggle")
        prepareFile()
        startWatching()
    }

    private func prepareFile() {
        try? FileManager.default.createDirectory(at: toggleDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: toggleFile.path) {
            FileManager.default.createFile(atPath: toggleFile.path, contents: nil)
        }
    }

    private func startWatching() {
        descriptor = open(toggleFile.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            guard let self, !self.isResetting else { return }
            self.toggle()
            self.resetSoon()
        }
        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }
        source.resume()
        self.source = source
    }

    private func resetSoon() {
        isResetting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.source?.cancel()
            self.source = nil
            try? FileManager.default.removeItem(at: self.toggleFile)
            FileManager.default.createFile(atPath: self.toggleFile.path, contents: nil)
            self.isResetting = false
            self.startWatching()
        }
    }
}
