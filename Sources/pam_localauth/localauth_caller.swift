import Foundation
import CoreGraphics
import Security
import LocalAuthentication

let kLocalAuthenticationTimeout = 60

func debug(_ s: Any) {
    #if DEBUG
    print(s)
    #endif
}

extension String: Error {}
struct Condition {
    var cond = pthread_cond_t()
    var mutex = pthread_mutex_t()

    init() throws {
        var ret = pthread_cond_init(&cond, nil)
        guard ret == 0 else {
            throw "Cannot initialize the condition: \(ret)"
        }

        ret = pthread_mutex_init(&mutex, nil)
        guard ret == 0 else {
            throw "Cannot initialize the mutex: \(ret)"
        }
    }

    mutating func destroy() {
        pthread_cond_destroy(&cond)
        pthread_mutex_destroy(&mutex)
    }

    // Manager thread: Prepare to dispatch work.
    mutating func arm() {
        pthread_mutex_lock(&mutex)
    }

    // Manager thread: Wait for work to complete or timeout.
    mutating func wait(timeout: Int) -> Bool {
        var ret: Int32 = -1
        var ctime = timeval()
        var expire = timespec(tv_sec: 0, tv_nsec: 0)

        gettimeofday(&ctime, nil)
        expire.tv_sec = ctime.tv_sec + timeout
        expire.tv_nsec = Int(UInt64(ctime.tv_usec) * NSEC_PER_USEC)

        ret = pthread_cond_timedwait(&cond, &mutex, &expire)

        if ret == ETIMEDOUT {
            return true
        }

        if ret != 0 {
            fatalError("Unknown errno \(ret) while beginning Condition wait")
        }

        return false
    }

    mutating func wait() {
        let ret = pthread_cond_wait(&cond, &mutex)
        if ret != 0 {
            fatalError("Unknown errno \(ret) while beginning Condition wait")
        }
    }

    // Worker thread: signal that work results are available.
    mutating func signal() {
        pthread_cond_signal(&cond)
    }

    mutating func performWork(_ block: () -> Void) {
        pthread_mutex_lock(&mutex)
        block()
        signal()
        pthread_mutex_unlock(&mutex)
    }
}

@available(OSX 10.11, *)
public func performBiometricAuthentication() -> Bool {
    let policy: LAPolicy
    if #available(OSX 10.15, *) {
        policy = LAPolicy.deviceOwnerAuthenticationWithWatch
    } else {
        return false
    }

    let ctx = LAContext()
    ctx.localizedFallbackTitle = ""
    if !ctx.canEvaluatePolicy(policy, error: nil) {
        return false
    }

    var lock: Condition
    var result: Bool? = nil

    do {
        lock = try Condition()
    } catch (let err) {
        debug("Condition init failed: \(err)")
        return false
    }

    lock.arm()
    ctx.evaluatePolicy(policy, localizedReason: "verify your identity") {
        (ok, err) in
        if let err = (err as NSError?), err.code == kLAErrorAppCancel {
            return
        }

        lock.performWork {
            if (ok) {
                debug("Authentication successful.")
                result = true
            } else {
                debug("Failed with error: \(String(describing: err))")
                result = false
            }
        }
    }
    debug("LA started...")

    if lock.wait(timeout: kLocalAuthenticationTimeout) {
        debug("Condition wait timed out")
        ctx.invalidate()
    }
    lock.destroy()
    
    if let result = result {
        return result
    }

    return false
}

public func checkConsoleOwnedBy(user: Int) -> Bool {
    guard let GUISessionInfo = (CGSessionCopyCurrentDictionary() as NSDictionary?) else {
        return false
    }

    var currentSessionID = noSecuritySession
    var currentSessionBits = SessionAttributeBits()
    guard SessionGetInfo(callerSecuritySession, &currentSessionID, &currentSessionBits) == errSecSuccess else {
        return false
    }

    // Need GUI access for the verification prompt.
    if currentSessionBits.contains(.sessionIsRemote) || !currentSessionBits.contains(.sessionHasGraphicAccess) {
        return false
    }

    // Now make sure the WindowServer session and security session are the same, and the authenticating
    // user is the one who owns the session.
    // XXX: kSCSecuritySessionID is undocumented
    guard let onConsoleSecID = (GUISessionInfo["kSCSecuritySessionID"] as? NSNumber),
          let isSessionConsole = (GUISessionInfo[kCGSessionOnConsoleKey] as? NSNumber),
          let sessionOwnerUID = (GUISessionInfo[kCGSessionUserIDKey] as? NSNumber) else {
        return false
    }

    if onConsoleSecID.int32Value != currentSessionID || !isSessionConsole.boolValue || sessionOwnerUID.intValue != user {
        return false
    }

    return true
}

// Try to determine whether the caller has a terminal.
// Implementation mostly a clone of
// https://github.com/python/cpython/blob/3.9/Lib/getpass.py
public func checkTerminalInteractive() -> Bool {
    if isatty(STDIN_FILENO) != 0 {
        return true
    }

    let fd = open("/dev/tty", O_RDWR | O_NOCTTY)
    if fd != -1 && isatty(fd) != 0 {
        close(fd)
        return true
    }

    return false
}
