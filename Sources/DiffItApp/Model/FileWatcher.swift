import Foundation

/// Watches one live file with a kqueue-backed dispatch source and reports changes, debounced.
///
/// Editors and agents usually save atomically (write a temp file, rename it over the original),
/// which fires `.delete`/`.rename` on the inode we hold. The watcher then closes the descriptor
/// and reopens the path, retrying briefly until the new file appears; if it never does, the
/// `onMissing` callback fires and watching stops.
final class FileWatcher: @unchecked Sendable {
    let path: String

    private let queue: DispatchQueue
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private var debounce: DispatchWorkItem?
    private var reopenAttempts = 0
    private var stopped = false

    private let onChange: @Sendable () -> Void
    private let onMissing: @Sendable () -> Void

    private static let debounceInterval: DispatchTimeInterval = .milliseconds(120)
    private static let reopenInterval: DispatchTimeInterval = .milliseconds(50)
    private static let maxReopenAttempts = 40     // 40 × 50 ms = 2 s
    private static let sharedQueue = DispatchQueue(label: "dev.diffit.filewatcher", qos: .userInitiated)

    /// Callbacks run on the watcher queue; hop to the main actor in the caller.
    init(path: String, onChange: @escaping @Sendable () -> Void, onMissing: @escaping @Sendable () -> Void) {
        self.path = path
        self.queue = Self.sharedQueue
        self.onChange = onChange
        self.onMissing = onMissing
    }

    deinit {
        closeDescriptor()
    }

    // MARK: - Control

    /// Returns false when the file could not be opened (watching is then off).
    @discardableResult
    func start() -> Bool {
        queue.sync { arm() }
    }

    func stop() {
        queue.sync {
            stopped = true
            debounce?.cancel()
            debounce = nil
            disarm()
        }
    }

    // MARK: - Private (watcher queue)

    private func arm() -> Bool {
        guard !stopped else { return false }
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return false }
        descriptor = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .delete, .rename, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self] in self?.handle(source.data) }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
        reopenAttempts = 0
        return true
    }

    /// Cancels the source; the cancel handler closes the descriptor.
    private func disarm() {
        if let source {
            source.cancel()
            self.source = nil
            descriptor = -1
        } else {
            closeDescriptor()
        }
    }

    private func closeDescriptor() {
        if descriptor >= 0 {
            close(descriptor)
            descriptor = -1
        }
    }

    private func handle(_ events: DispatchSource.FileSystemEvent) {
        guard !stopped else { return }
        if !events.isDisjoint(with: [.delete, .rename, .revoke]) {
            // The inode is gone; follow the path to its replacement.
            disarm()
            reopenLater()
        }
        scheduleChange()
    }

    private func reopenLater() {
        guard !stopped else { return }
        queue.asyncAfter(deadline: .now() + Self.reopenInterval) { [weak self] in
            guard let self, !self.stopped, self.source == nil else { return }
            if self.arm() {
                self.scheduleChange()
            } else if self.reopenAttempts < Self.maxReopenAttempts {
                self.reopenAttempts += 1
                self.reopenLater()
            } else {
                self.onMissing()
            }
        }
    }

    private func scheduleChange() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.stopped else { return }
            self.onChange()
        }
        debounce = work
        queue.asyncAfter(deadline: .now() + Self.debounceInterval, execute: work)
    }
}
