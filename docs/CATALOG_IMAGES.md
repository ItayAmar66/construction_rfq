# Catalog product images

## Diagnosis (production import)

Firestore `catalogProducts` / `catalogVariants` documents store:

| Field | After import |
|-------|----------------|
| `image.localPath` | Source file path from dataset (e.g. `images/foo.webp`) |
| `imageUrl` / `imageThumbUrl` | Usually **null** until Storage upload |
| `image.url` / `image.thumbUrl` | Usually **empty** in embedded `image` map |

The catalog import CLI writes metadata only. It does **not** upload binaries to Firebase Storage.

## UI behavior

- `CatalogImageUrl.resolveDisplayUrl()` tries, in order: `thumbUrl` → `url` → Storage download URL derived from `localPath` under `catalog/images/`.
- If the file is not in Storage, `Image.network` fails and the app shows a neutral placeholder (no fake images).

## Enable images in production

1. Upload dataset images to Storage under `catalog/images/` (same relative paths as `localPath`).
2. Optionally run a future `catalog_upload_images` tool to set `imageUrl` / `imageThumbUrl` on Firestore docs.
3. Re-run light verify — image fields remain optional; URLs are optional until upload completes.

Example upload (adjust paths):

```bash
export BUCKET=construction-rfq-itay-20-2eee0.firebasestorage.app
gsutil -m cp -r "$CATALOG_DATA_ROOT/assets/images/*" "gs://$BUCKET/catalog/images/"
```

Until upload completes, placeholders are expected and correct.
