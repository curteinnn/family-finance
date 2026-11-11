# Family Finance Mobile

Flutter mobile client for the NestJS API in `../backend`.

## Run on Android emulator

1. Start the backend and make sure its development database migrations are current.
2. From this directory, run:

   ```cmd
   flutter pub get
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
   ```

`10.0.2.2` is the Android emulator's route to the host computer. For a physical Android phone, set `API_BASE_URL` to the computer's LAN address, keep both devices on the same network, and allow the backend through the development firewall. Debug builds allow local HTTP; release builds should use HTTPS.

The Android SDK must be installed through Android Studio before building or running on Android. Check setup with `flutter doctor`, then accept Android licenses with `flutter doctor --android-licenses`.

## Included flows

- Login, secure token storage, access token refresh, and logout.
- Role-aware family and balance overview.
- Parent creates and cancels transfers; child confirms or rejects pending transfers.
- Child records expenses; parent can void them with a reason.
- Transaction history, monthly/lifetime overview data, and notifications.

Photo/document upload is deferred. Accounts must already exist in the backend; this mobile client does not create admin, parent, or child accounts.

See the [backend API guide](../backend/docs/backend-api.md) for routes and request bodies. The API base URL is configured with the non-secret `API_BASE_URL` Dart define; no environment file is needed by the mobile app.
