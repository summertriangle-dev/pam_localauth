// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "pam_localauth",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "libpam", targets: ["libpam"]),
        .library(name: "pam_localauth", type: .dynamic, targets: ["pam_localauth"]),
        .executable(name: "LocalAuthenticationHelper", targets: ["LocalAuthenticationHelper"]),
        // .executable(name: "Install", targets: ["Install"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .systemLibrary(name: "libpam"),
        .target(name: "pam_localauth", dependencies: ["libpam"], linkerSettings: [.linkedLibrary("pam")]),
        .target(name: "LocalAuthenticationHelper", dependencies: ["pam_localauth", "libpam"]),
        // .target(name: "Install", dependencies: [])
    ]
)
