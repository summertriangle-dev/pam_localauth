import Darwin
import libpam

public typealias pam_handle_t = OpaquePointer

func getCallingUserID(forName name: String) -> Int? {
    let bufSize = sysconf(_SC_GETPW_R_SIZE_MAX)
    var sbuf = [Int8](repeating: 0, count: bufSize)
    var pwent = passwd()
    var pwentp: UnsafeMutablePointer<passwd>? = nil

    let status = name.withCString { getpwnam_r($0, &pwent, &sbuf, bufSize, &pwentp) }
    if (status != 0 || pwentp == nil) {
        return nil
    }

    return Int(pwent.pw_uid)
}

@_cdecl("pam_sm_authenticate")
public func pam_sm_authenticate_oschk(
    pamh: pam_handle_t,
    flags: Int32,
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
) -> Int32 {
    if #available(OSX 10.13, *) {
        return pam_sm_authenticate(pamh: pamh, flags: flags, argc: argc, argv: argv)
    } else {
        return Int32(PAM_AUTH_ERR)
    }
}

@available(OSX 10.13, *)
func pam_sm_authenticate(
    pamh: pam_handle_t,
    flags: Int32,
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
) -> Int32 {
    var username: UnsafePointer<Int8>? = nil
    guard pam_get_user(pamh, &username, nil) == PAM_SUCCESS else {
        return Int32(PAM_AUTHINFO_UNAVAIL)
    }

    guard let usernameN = username,
          let uid = getCallingUserID(forName: String(cString: usernameN)) else {
        return Int32(PAM_USER_UNKNOWN)
    }

    guard checkConsoleOwnedBy(user: uid) && checkTerminalInteractive() else {
        return Int32(PAM_AUTH_ERR)
    }

    guard performBiometricAuthentication() else {
        return Int32(PAM_AUTH_ERR)
    }

    return Int32(PAM_SUCCESS)
}

@_cdecl("pam_sm_setcred")
public func pam_sm_setcred(
    pamh: pam_handle_t,
    flags: Int32,
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
) -> Int32 {
    return Int32(PAM_SUCCESS)
}

@_cdecl("pam_sm_acct_mgmt")
public func pam_sm_acct_mgmt(
    pamh: pam_handle_t,
    flags: Int32,
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
) -> Int32 {
    return Int32(PAM_SUCCESS)
}

@_cdecl("pam_sm_close_session")
public func pam_sm_close_session(
    pamh: pam_handle_t,
    flags: Int32,
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
) -> Int32 {
    return Int32(PAM_SUCCESS)
}

@_cdecl("pam_sm_open_session")
public func pam_sm_open_session(
    pamh: pam_handle_t,
    flags: Int32,
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
) -> Int32 {
    return Int32(PAM_SUCCESS)
}

@_cdecl("pam_sm_chauthtok")
public func pam_sm_chauthtok(
    pamh: pam_handle_t,
    flags: Int32,
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
) -> Int32 {
    return Int32(PAM_SERVICE_ERR)
}
