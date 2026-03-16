# App Store Privacy Guide

This file is a practical reference for filling App Store Connect privacy-related fields for the current version of `Smart Swipe`.

Important: this reflects the current codebase state only. If you later add analytics, crash reporting, accounts, subscriptions, cloud sync, or external APIs, update these answers.

## Current technical assumptions from the project

Based on the current codebase:

- the app uses Apple Photos access
- media review and grouping are handled locally on-device
- the app now supports optional Sign in with Apple
- the app can sync cleanup progress and preferences through the user's private CloudKit database
- no third-party analytics SDKs were found
- no advertising SDKs were found
- no custom backend/API owned by the developer was found
- user progress and preferences are stored locally with `UserDefaults`

## App Privacy likely answers

### Does this app collect data?

This now requires a manual review in App Store Connect.

Reason:
- the app stores a Sign in with Apple user identifier locally
- the app may write progress/preferences to the user's private CloudKit container for restore and sync
- there is still no third-party analytics, ads, or developer-owned backend in the project

Conservative review posture:
- treat Sign in with Apple and CloudKit sync as data that is associated with the user's account and review Apple's latest questionnaire wording carefully before selecting `No`
- do not mark anything as tracking

### Does this app track users?

- `No`

### Data linked to the user

Manual review suggested:

- `User ID` because Sign in with Apple stores a stable Apple user identifier for restore/sync
- possibly `Product Interaction` if you choose to disclose synced progress state conservatively

### Data used to track the user

- `None`

## Privacy Policy URL

Use this public Privacy Policy URL in App Store Connect:

- `https://yasarkah.github.io/Swipe-Gallery/privacy-policy.html`

Related public URLs:

- Support: `https://yasarkah.github.io/Swipe-Gallery/index.html`
- Terms: `https://yasarkah.github.io/Swipe-Gallery/terms-of-use.html`

Project files prepared for this:

- `docs/privacy-policy.md`
- `docs/terms-of-use.md`
- `docs/privacy-policy.html`
- `docs/terms-of-use.html`
- `docs/index.html`

## Recommended publication setup

1. Publish the `docs/` folder through GitHub Pages
2. Confirm the three public URLs above open without authentication
3. Put the privacy policy URL into App Store Connect
4. Keep the same URLs in the in-app settings screen

## Must-review before submission

Re-check this file if you add any of the following:

- Firebase
- Sentry
- Crashlytics
- RevenueCat
- StoreKit subscriptions
- your own backend API
- external image processing
- analytics or attribution SDKs
- ads

## Support details

Current support email in project files:

- `kahramaneryasar@gmail.com`
