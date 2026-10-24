# App Store: Scorekeep

- App: **Scorekeep: Game Score Keeper** (home screen name "Scorekeep"; several
  "ScoreKeep ..." apps already exist, so the bare name is likely taken)
- Bundle ID `co.scorekeep.app`, team `2837Q6TK6Y`, version in `ios/project.yml`
  (`MARKETING_VERSION`), build number = `ios-release.yml` run number.
- Listing text: `ios/fastlane/metadata/` (pushed on every release). Screenshots are
  generated fresh by each release, never committed.
- Privacy URL https://scorekeep.co/privacy.html, support URL https://scorekeep.co/support.html
  (both in `docs/`, so they deploy with the website).

## How to ship
Dispatch `ios-release.yml` (GitHub MCP `actions_run_trigger`, or the Actions tab):
- `submit_for_review=false`: TestFlight build + listing + screenshots.
- `submit_for_review=true`: same, then submits for review with automatic release.
The workflow re-runs all tests first and fails with a clear message when setup is missing.

## Signing
Unsigned archive, then `xcodebuild -exportArchive -allowProvisioningUpdates` with
the API key signs it with a cloud-managed distribution certificate. That needs an
API key with the **Admin** role (or App Manager with access to certificates).
If export fails on signing, check the key's role first.

## One-time setup (owner, App Store Connect web UI)
These can't be done through Apple's API with an API key:
1. GitHub secret `ASC_API_KEY_P8` on this repo = contents of `AuthKey_7MPPJ2254M.p8`
   (same key BroadwayScorecard-app uses). Key ID and issuer ID default in the workflow.
2. App Store Connect > Apps > + > New App: iOS, name above, English (U.S.),
   bundle ID `co.scorekeep.app` (the release workflow registers it if missing),
   SKU `scorekeep`.
3. App Privacy: "No, we do not collect data from this app".
4. Age Rating: answer None/No to everything (result 4+).
5. Pricing and Availability: Free, all countries.
6. App Review Information: contact name, phone and email (kept out of this public repo).

## Privacy answers (checked against the code 2026-10-24)
- Stored on device only (UserDefaults): players, scores, colors, sort, increment,
  sound setting, saved games. No network calls, no analytics, no crash reporting,
  no third-party SDKs.
- `PrivacyInfo.xcprivacy`: UserDefaults reason CA92.1, no tracking, no collected data.
- `ITSAppUsesNonExemptEncryption = NO`: no encryption, so no export compliance question.
- Update this section if a network call or SDK is ever added.

## Review risks
- **4.2 Minimum functionality** (BroadwayScorecard-app was rejected under 4.2.2):
  Scorekeep is fully native with haptics, synthesized sound, undo, end-game
  celebration, history and VoiceOver support. Mention these in review notes if asked.
- **iPad:** the app is universal and reviewers often use an iPad. Check the iPad
  screenshots before every submission.
- No trademarked game names in keywords (Guideline 2.3.7).

## Release history
| Version | Build | Date | Notes |
|---|---|---|---|
| 1.0.0 | - | - | First submission pending one-time setup |
