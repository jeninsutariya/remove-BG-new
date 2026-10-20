# remove-BG-new

An iOS app to remove image backgrounds, place text behind the subject, edit the result and export it.

## Free vs Premium

| Feature | Free | Premium |
| --- | --- | --- |
| Remove background | Limited uses per day | Unlimited |
| Text behind subject | Limited uses per day | Unlimited |
| Bulk Remove export | 3 images per day | Unlimited |
| Export resolution | Up to 2048 px on the long side | Full resolution |
| JPEG export quality | 0.85 | 0.95 |
| Watermark on exported images | Yes (bottom-left corner) | No watermark |
| Ads | Shown | **Ads removed** |
| Premium upgrade prompts | Shown when a limit is reached | Never |

## Premium features

- **Ads removed**: no ads anywhere in the app.
- **No watermark**: exported images are clean.
- **Full-resolution export (HD)**: no 2048 px cap on the long side.
- **Higher JPEG quality**: 0.95 instead of 0.85.
- **Unlimited background removal**: no daily limit.
- **Unlimited Text Behind Subject**: no daily limit.
- **Unlimited Bulk Remove export**: no 3-images-per-day cap, including ZIP export.
- **Restore purchases**: Premium can be restored on any device with the same Apple ID.

## How Premium works

- Purchases use StoreKit through SwiftyStoreKit (`IAPManager.swift`).
- Premium unlocks only after the App Store receipt is verified.
- `PaywallManager` enforces the free limits and shows the Premium screen (`ProUpgradeVC`) when one is reached.
- `ExportQuality.current` decides Standard (free) or Full (premium) quality for every export path.

## Dependencies

- Lottie
- SwiftyStoreKit
- SDWebImage
