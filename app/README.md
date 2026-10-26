# carli (iOS)

Native iOS client for carli, built with Flutter. It talks to the Laravel API in `../backend` with Sanctum personal access tokens.

## Run

```sh
flutter run --dart-define=API_URL=http://<host>:8180/api
```

`API_URL` defaults to `http://192.168.0.20:8180/api`. Debug builds include a component catalog at `/dev/catalogo`, linked from the login and "Más" screens.

## Checks

```sh
flutter analyze
flutter test
flutter test integration_test -d <simulator> --dart-define=API_URL=http://127.0.0.1:8181/api
```

The integration test logs in with the backend demo seed user (`SEED_DEMO_USER=true`).

## Generated assets

- `node tool/generate-ios-assets.mjs` renders the app icon and launch image from `frontend/scripts/lib/carli-mark.mjs`.
- `node tool/generate-icon-names.mjs` rebuilds `lib/ui/icon_names.dart` from the Angular icon registry.
