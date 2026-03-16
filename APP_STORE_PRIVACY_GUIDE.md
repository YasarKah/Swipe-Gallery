# App Store Privacy Guide

This file is a practical reference for filling App Store Connect privacy-related fields for the current version of `Smart Swipe`.

Important: this reflects the current codebase state only. If you later add analytics, crash reporting, accounts, subscriptions, cloud sync, or external APIs, update these answers.

## Current technical assumptions from the project

Based on the current codebase:

- the app uses Apple Photos access
- media review and grouping are handled locally on-device
- no third-party analytics SDKs were found
- no advertising SDKs were found
- no account system was found
- no remote API/network data collection code was found
- user progress and preferences are stored locally with `UserDefaults`

## App Privacy likely answers

### Does this app collect data?

Most likely answer for the current build:

- `No`, if you are not sending any user data off-device

Reason:
- photo access alone does not automatically mean "data collected" for App Store privacy labels if the data stays on-device and is not transmitted off the device by you or a third party

### Does this app track users?

- `No`

### Data linked to the user

- `None`, based on the current implementation

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
- Sign in with Apple or any account system
- your own backend API
- external image processing
- analytics or attribution SDKs
- ads

## Support details

Current support email in project files:

- `kahramaneryasar@gmail.com`
