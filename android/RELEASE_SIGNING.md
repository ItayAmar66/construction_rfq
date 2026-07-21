# Android release signing

Release builds (`flutter build apk --release`, `flutter build appbundle --release`)
require `android/key.properties`, which is intentionally **not committed**
(see `.gitignore`). Without it, `android/app/build.gradle` fails the build
with a clear error instead of silently falling back to debug signing.

## One-time setup

1. Generate an upload keystore (keep this file and its passwords out of git,
   password managers / a secrets vault only):

   ```
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```

2. Copy the template and fill in real values:

   ```
   cp android/key.properties.example android/key.properties
   ```

   ```
   storePassword=<keystore password>
   keyPassword=<key password>
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```

3. Build:

   ```
   flutter build appbundle --release
   flutter build apk --release
   ```

`android/key.properties` and any `*.jks` / `*.keystore` files are gitignored.
Never commit them or paste their contents into chat, issues, or CI logs.
