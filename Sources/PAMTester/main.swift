import libpam

typealias pam_handle_t = OpaquePointer

func getPwName(uid: uid_t) -> String {
    let bufSize = sysconf(_SC_GETPW_R_SIZE_MAX)
    var sbuf = [Int8](repeating: 0, count: bufSize)
    var pwent = passwd()
    var pwentp: UnsafeMutablePointer<passwd>? = nil

    guard getpwuid_r(uid, &pwent, &sbuf, bufSize, &pwentp) == 0 else {
        fatalError("cannot look up the current user's name")
    }

    return String(cString: pwent.pw_name)
}

guard CommandLine.arguments.count > 1 else {
    print("usage: PAMTester <service name>")
    exit(1)
}

var handle: pam_handle_t! = nil
let sret = pam_start(CommandLine.arguments[1], getPwName(uid: getuid()), nil, &handle)
if sret != 0 {
    fatalError("cannot initialize PAM")
}

let aret = pam_authenticate(handle, 0)
if aret == 0 {
    print("OK")
    exit(0)
} else {
    print("Error: \(aret)")
    exit(aret)
}

pam_end(handle, 0)
