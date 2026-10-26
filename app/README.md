# carli (iOS)

Native iOS client for carli, built with Flutter. It talks to the Laravel API in `../backend` with Sanctum personal access tokens.

## Run

```sh
flutter run --dart-define=API_URL=http://<host>:8180/api
```

`API_URL` defaults to `http://MacBook-Pro-van-Yurest.local:8180/api`. Debug builds include a component catalog at `/dev/catalogo`, linked from the login and "Más" screens.

## Checks

```sh
flutter analyze
flutter test            # or `make test-app` from the repo root
flutter test integration_test -d <simulator> --dart-define=API_URL=http://127.0.0.1:8181/api
```

The integration test logs in with the backend demo seed user (`SEED_DEMO_USER=true`).

## Generated assets

- `node tool/generate-ios-assets.mjs` renders the app icon and launch image from the logo geometry in `tool/lib/carli-mark.mjs` (PNG encoding in `tool/lib/png.mjs`).

## Icons

`lib/ui/icon_names.dart` is the hand-maintained source of truth for the kebab-case icon names stored by the backend (`shopping-cart`, `piggy-bank`…). To add one, add an entry that maps the name to a `HugeIconsStrokeRounded` glyph.
