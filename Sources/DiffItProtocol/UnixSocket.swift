import Foundation

public enum UnixSocketError: Error, Equatable {
    case pathTooLong
    case socket(Int32)
    case connect(Int32)
    case bind(Int32)
    case listen(Int32)
    case accept(Int32)
    case write(Int32)
    case read(Int32)
    case timeout
    /// Another process already answers on this socket path.
    case alreadyInUse
}

/// Minimal blocking Darwin wrappers for the CLI ↔ app socket.
public enum UnixSocket {
    // MARK: - Client

    /// Returns a connected fd, or nil if nothing is listening (ECONNREFUSED / ENOENT).
    /// Other failures throw.
    public static func connect(path: String) throws -> Int32? {
        var addr = try makeAddress(path)
        let fd = try makeSocket()
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if result == 0 { return fd }
        let err = errno
        close(fd)
        if err == ECONNREFUSED || err == ENOENT { return nil }
        throw UnixSocketError.connect(err)
    }

    // MARK: - Server

    /// Binds and listens on `path`. A stale socket file left by a crash is unlinked;
    /// a live one (something answers `connect`) raises `.alreadyInUse`.
    public static func listen(path: String, backlog: Int32 = 16) throws -> Int32 {
        if let fd = try connect(path: path) {
            close(fd)
            throw UnixSocketError.alreadyInUse
        }
        unlink(path)

        var addr = try makeAddress(path)
        let fd = try makeSocket()
        let bound = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else { let err = errno; close(fd); throw UnixSocketError.bind(err) }
        chmod(path, 0o600)
        guard Darwin.listen(fd, backlog) == 0 else { let err = errno; close(fd); throw UnixSocketError.listen(err) }
        return fd
    }

    /// Blocks until a client connects. Returns nil if the listening socket was closed.
    public static func accept(_ listeningFD: Int32) throws -> Int32? {
        while true {
            let fd = Darwin.accept(listeningFD, nil, nil)
            if fd >= 0 {
                setNoSigPipe(fd)
                return fd
            }
            let err = errno
            if err == EINTR { continue }
            if err == EBADF || err == ECONNABORTED { return nil }
            throw UnixSocketError.accept(err)
        }
    }

    // MARK: - I/O

    public static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard var cursor = buffer.baseAddress else { return }
            var remaining = buffer.count
            while remaining > 0 {
                let n = Darwin.write(fd, cursor, remaining)
                if n < 0 {
                    let err = errno
                    if err == EINTR || err == EAGAIN { continue }
                    throw UnixSocketError.write(err)
                }
                cursor += n
                remaining -= n
            }
        }
    }

    /// Reads up to (not including) the first `\n`. Returns nil on EOF with nothing buffered.
    /// `timeout` is an overall deadline for the whole line.
    public static func readLine(_ fd: Int32, timeout: TimeInterval? = nil) throws -> Data? {
        let deadline = timeout.map { Date(timeIntervalSinceNow: $0) }
        var line = Data()
        var chunk = [UInt8](repeating: 0, count: 65_536)
        while true {
            if let deadline { try wait(fd, until: deadline) }
            let n = chunk.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
            if n < 0 {
                let err = errno
                if err == EINTR { continue }
                throw UnixSocketError.read(err)
            }
            if n == 0 { return line.isEmpty ? nil : line }
            if let newline = chunk[0..<n].firstIndex(of: 0x0A) {
                line.append(contentsOf: chunk[0..<newline])
                return line
            }
            line.append(contentsOf: chunk[0..<n])
        }
    }

    public static func close(_ fd: Int32) {
        _ = Darwin.close(fd)
    }

    // MARK: - Private

    private static func makeSocket() throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw UnixSocketError.socket(errno) }
        setNoSigPipe(fd)
        return fd
    }

    private static func setNoSigPipe(_ fd: Int32) {
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
    }

    private static func makeAddress(_ path: String) throws -> sockaddr_un {
        var addr = sockaddr_un()
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard bytes.count < capacity else { throw UnixSocketError.pathTooLong }
        addr.sun_family = sa_family_t(AF_UNIX)
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        return addr
    }

    private static func wait(_ fd: Int32, until deadline: Date) throws {
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { throw UnixSocketError.timeout }
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let result = poll(&pfd, 1, Int32((remaining * 1000).rounded(.up)))
        if result == 0 { throw UnixSocketError.timeout }
        if result < 0 {
            let err = errno
            if err == EINTR { return }
            throw UnixSocketError.read(err)
        }
    }
}
