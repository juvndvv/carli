# carli iOS (SwiftUI)

Native rewrite of the Flutter app in `../app`, built for iOS 26+ with Liquid Glass.
The Flutter app stays until every screen is migrated.

- Project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`
  (`Carli.xcodeproj` is not committed).
- `scripts/sim.sh` builds, installs and launches on the Simulator;
  `scripts/sim.sh shot login` also saves light and dark screenshots to `screenshots/`.
- Tests: `xcodebuild test -project Carli.xcodeproj -scheme Carli -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

Layout: `Carli/App` (entry, root), `Core` (API, auth, theme), `UI` (shared views), `Features/<screen>`.
