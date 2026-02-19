import Foundation

private func darwinCallback(
    center: CFNotificationCenter?,
    observer: UnsafeMutableRawPointer?,
    name: CFNotificationName?,
    object: UnsafeRawPointer?,
    userInfo: CFDictionary?
) {
    guard let pointer = observer else { return }
    let closure = Unmanaged<DarwinObservation.Closure>
        .fromOpaque(pointer)
        .takeUnretainedValue()
    closure.invoke()
}

public final class DarwinNotificationCenter: Sendable {
    public static let shared = DarwinNotificationCenter()
    private init() {}

    private var center: CFNotificationCenter {
        CFNotificationCenterGetDarwinNotifyCenter()
    }

    public func post(_ name: String) {
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }

    public func addObserver(
        name: String,
        callback: @escaping @Sendable () -> Void
    ) -> DarwinObservation {
        let observation = DarwinObservation(callback: callback)
        CFNotificationCenterAddObserver(
            center, observation.observerPointer, darwinCallback,
            name as CFString, nil, .deliverImmediately
        )
        return observation
    }
}

public final class DarwinObservation: @unchecked Sendable {
    fileprivate final class Closure: @unchecked Sendable {
        let invoke: @Sendable () -> Void
        init(_ fn: @escaping @Sendable () -> Void) { self.invoke = fn }
    }

    fileprivate let closure: Closure
    fileprivate let observerPointer: UnsafeRawPointer
    private var isCancelled = false

    init(callback: @escaping @Sendable () -> Void) {
        self.closure = Closure(callback)
        self.observerPointer = UnsafeRawPointer(
            Unmanaged.passUnretained(self.closure).toOpaque()
        )
    }

    deinit { cancel() }

    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        // 同步移除观察者，避免 deinit 后 closure 被释放导致 use-after-free
        // Darwin notify center (CFNotificationCenterGetDarwinNotifyCenter) 的移除操作是线程安全的
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observerPointer, nil, nil
        )
    }
}
