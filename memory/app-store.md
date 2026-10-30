# App Store: Scorekeep

- App: **Scorekeep: Score Tracker**, subtitle "Simple Score Keeper, No Ads"
  (home screen name "Scorekeep"). Chosen by the owner 2026-10-26 from App Store
  search suggestions ("score keeper" and "score tracker" lead) plus GPT-4o and
  Gemini input. Owner rejected "Game Score Keeper" as an awkward phrase.
- Bundle ID `co.scorekeep.app`, team `2837Q6TK6Y`, version in `ios/project.yml`
  (`MARKETING_VERSION`), build number = `ios-release.yml` run number.
- Listing text: `ios/fastlane/metadata/` (pushed on every release). Screenshots are
  generated fresh by each release, never committed.
- Privacy URL https://scorekeep.co/privacy.html, support URL https://scorekeep.co/support.html
- Support contact on support.html: tom@broadwayscorecard.com (owner's choice until a
  Scorekeep address exists; never the owner's personal address). Smoke test requires a mailto.
  (both in `docs/`, so they deploy with the website).

## How to ship
Dispatch `ios-release.yml` (GitHub MCP `actions_run_trigger`, or the Actions tab):
- Default: runs the tests, builds, uploads to TestFlight, pushes listing + screenshots.
  Then ask the owner to install that build number from TestFlight and try it.
- `submit_for_review=true tested_build=<N>`: only after the owner approved build N.
  Skips building, pushes listing + screenshots and submits build N with automatic
  release. Refuses without tested_build.
`ios-review-reply.yml` (manual): takes a Drive file ID (shared "Anyone with the link")
and a step: check (length + still frames artifact), attach (review attachment + notes),
submit (also resubmits). Used for Apple's 2026-10-29 request for a device recording.
`ios-review.yml` (manual, read-only): version state, review submissions, review
notes and attachments. Apple's own messages are not in the API; read them in App
Store Connect or the owner's email.

The owner reaches builds through the internal TestFlight group "Owner" (every
build, automatic). `ios-testflight-access.yml` creates it and adds the account
holder and admins; re-run it if a new admin needs builds.
2026-10-26: a submission was started before the owner had tried the app; they
stopped it ("I haven't even played with this app"). That is why tested_build exists.

Only the submit run attaches the build to the version (a listing-only run leaves
"Add Build" on the version page). The listing lane also answers the content rights
question ("no third-party content"); App Review rejects a submission without it
(release run 5, 2026-10-26).

## Signing
Unsigned archive, then `xcodebuild -exportArchive -allowProvisioningUpdates` with
the API key signs it with a cloud-managed distribution certificate. That needs an
API key with the **Admin** role (or App Manager with access to certificates).
If export fails on signing, check the key's role first.

## One-time setup (owner, App Store Connect web UI)
These can't be done through Apple's API with an API key:
1. GitHub secret `ASC_API_KEY_P8` on this repo = contents of `AuthKey_7MPPJ2254M.p8`
   (same key BroadwayScorecard-app uses). Key ID and issuer ID default in the workflow.
2. App Store Connect > Apps > + > New App (done 2026-10-26 as "ScoreKeep App"; the release renames it): iOS, English (U.S.),
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
| 1.0.0 | 2, 4, 5 | 2026-10-26 | TestFlight builds; listing + screenshots pushed. Submit failed on missing content rights (fixed) |
| 1.0.0 | 7 | 2026-10-28 | TestFlight. Owner tested earlier build: all good except no sound (silent switch). Fixed in PR #10. Owner tested build 7 (sound works) |
| 1.0.0 | 7 | 2026-10-29 | Submitted for App Review (release run 8, automatic release). Review notes not set; support page links to GitHub issues only |
