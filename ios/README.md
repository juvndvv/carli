# carli iOS (SwiftUI)

Native iOS app, built for iOS 26+ with Liquid Glass. It replaced the Flutter app, removed on 2026-10-28.

- Project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`
  (`Carli.xcodeproj` is not committed).
- `scripts/sim.sh` builds, installs and launches on the Simulator;
  `scripts/sim.sh shot login` also saves light and dark screenshots to `screenshots/`.
- Tests: `xcodebuild test -project Carli.xcodeproj -scheme Carli -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

Layout: `Carli/App` (entry, root), `Core` (API, auth, theme), `UI` (shared views), `Features/<screen>`.
