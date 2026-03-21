# HireLocal (SmallBusinessApp)

HireLocal is an iOS SwiftUI app for local businesses and workers.

## What it does

- Manual sign up and log in (email/password)
- Sign in with Apple
- Create posts for:
  - Businesses hiring employees
  - Workers looking for jobs
- Browse and filter all posts by type and business category
- View post details and contact info
- View/delete your own posts
- Local persistence (users, session, posts) so data remains after app relaunch

## Open in Xcode

1. Open `SmallBusinessApp.xcodeproj`.
2. Select the `SmallBusinessApp` scheme.
3. Run on an iOS Simulator or device.

## Apple Sign In notes

- The app includes the `Sign in with Apple` entitlement (`SmallBusinessApp/SmallBusinessApp.entitlements`).
- For real device testing, ensure your Apple Developer team and bundle identifier are configured in Xcode signing settings.

## Project structure

- `SmallBusinessApp/Sources/App` - app entry and root routing
- `SmallBusinessApp/Sources/ViewModels` - `AppStore` business logic and session/auth/post management
- `SmallBusinessApp/Sources/Views` - auth, feed, create post, detail, account screens
- `SmallBusinessApp/Sources/Services` - JSON persistence and CloudKit helper
- `SmallBusinessApp/Resources/Assets.xcassets` - app colors and generated AppIcon set
- `project.yml` - XcodeGen project spec

## Regenerate project (optional)

If you update `project.yml`:

```bash
xcodegen generate
```

After regenerating, open the target in Xcode and confirm `Signing & Capabilities` still shows `Sign in with Apple` before testing Apple Sign In on a device.
