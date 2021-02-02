# pam_localauth

pam_localauth is a PAM module that allows the user to authenticate using a paired
Apple Watch (via LocalAuthentication, Mac OS X 10.15+).

## Install

- Copy libpam_localauth.dylib to a secure location. 
  (`/Library/pam_localauth/libpam_localauth.dylib` is recommended)
- Add the library to the PAM service file you want to use it with. Example:
  /etc/pam.d/sudo
  ```
  # sudo: auth account password session
  auth       sufficient     pam_smartcard.so
  auth       sufficient     /Library/pam_localauth/libpam_localauth.dylib
  auth       required       pam_opendirectory.so
  account    required       pam_permit.so
  password   required       pam_deny.so
  session    required       pam_permit.so
  ```
