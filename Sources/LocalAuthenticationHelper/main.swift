import Darwin
import pam_localauth

@available(OSX 10.13, *)
func main() {
    let result = pam_localauth.performBiometricAuthentication()
    print(result)
}

if #available(OSX 10.13, *) {
    main()
}
