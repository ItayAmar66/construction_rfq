# Firebase Storage CORS

Catalog images on Flutter web require CORS on the Storage bucket.

## Apply (manual — not run by CI)

```bash
gcloud storage buckets update gs://construction-rfq-itay-20-2eee0.firebasestorage.app \
  --cors-file=tools/firebase/storage_cors.json
```

Config allows localhost dev origins and Firebase Hosting origins for `GET`, `HEAD`, `OPTIONS`.

After applying, hard-refresh the web app. Failed loads still show placeholders in the app.
