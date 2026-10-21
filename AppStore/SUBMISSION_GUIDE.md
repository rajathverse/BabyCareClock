# Putting Baby Care Clock on the App Store — step by step

Everything inside the project is already done: app icon, privacy manifest, encryption setting, version 1.0 (build 1), screenshots, store text. What's left needs **you**, because it involves your Apple ID, money, and Apple's websites.

Time needed: about 1 hour of clicking, plus **1–2 days waiting** for Apple to approve your membership, plus **1–3 days** for App Review.

---

## Step 1 — Join the Apple Developer Program ($99 / year)
Right now your Xcode uses a free "Personal Team". Free teams **cannot** publish to the App Store.

1. Go to https://developer.apple.com/programs/enroll/ and tap **Start Your Enrollment**.
2. Sign in with your Apple ID (two-factor authentication must be on).
3. Choose **Individual / Sole Proprietor**. (An "Organization" needs a D-U-N-S number; skip that unless you have a company.)
4. Pay the $99 fee.
5. Wait for the email "Welcome to the Apple Developer Program" (usually within 48 hours).

Your App Store "seller" name will be your legal name, e.g. *Rajath Chowdhury*.

## Step 2 — Put the privacy policy online
Apple needs a web link to a privacy policy.

1. The contact email in `AppStore/PRIVACY_POLICY.html` is rajathverse@gmail.com. Change it there if you want a different one.
2. Upload it somewhere public. Easiest options:
   - On www.rajathverse.com, upload `AppStore/PRIVACY_POLICY.html` as `https://www.rajathverse.com/babycareclock/privacy` and `AppStore/SUPPORT.html` as `https://www.rajathverse.com/babycareclock/`
   - (If your site builder doesn't take HTML files, copy the text into two new pages at those addresses.)
3. Open the link in Safari to check it works. Keep the link handy.

## Step 3 — Point Xcode at your paid team
1. Xcode → **Settings…** (⌘,) → **Accounts**. Your Apple ID should now show a team that does **not** say "(Personal Team)". If not, click your Apple ID and **Download Manual Profiles**, or remove and re-add the account.
2. Open `ChildCareClock.xcodeproj`.
3. In the left sidebar click the blue **ChildCareClock** project icon → under TARGETS click **ChildCareClock** (and repeat for **ChildCareClockWidget**) → **Signing & Capabilities** tab.
4. Make sure **Automatically manage signing** is ticked.
5. In **Team**, pick your new paid team (not the Personal Team).
6. If it says the bundle identifier is unavailable, change `com.rajathverse.childcareclock` to something unique such as `com.rajathverse.childcareclock2` and remember it for Step 4. The widget's bundle ID must start with the app's (e.g. `com.rajathverse.childcareclock2.widget`), and the App Group in `Shared/CarePersistence.swift` and both `Config/*.entitlements` files must match a group you register.

## Step 4 — Create the app in App Store Connect
1. Go to https://appstoreconnect.apple.com and sign in.
2. **Apps** → the blue **+** → **New App**.
3. Fill in:
   - Platforms: **iOS**
   - Name: `Baby Care Clock` (if taken, try `Baby Care Clock: Baby Care`)
   - Primary language: English
   - Bundle ID: pick `com.rajathverse.childcareclock` from the dropdown. If it's not listed, wait a minute after Step 3 and reload, or register it at https://developer.apple.com/account/resources/identifiers
   - SKU: `childcareclock-001`
   - User access: Full Access
4. Click **Create**.

## Step 5 — Upload the app from Xcode
1. In Xcode's top bar, set the run destination (next to the ▶ button) to **Any iOS Device (arm64)**. Archiving does not work with a simulator selected.
2. Menu **Product → Archive**. Wait a couple of minutes.
3. The **Organizer** window opens with your archive selected. Click **Distribute App**.
4. Choose **App Store Connect** → **Distribute** (keep the default options; let Xcode manage signing).
5. Wait for "Upload Successful".
6. After 5–30 minutes Apple emails you that the build has finished processing.

> If the upload says build 1 was already used, bump the build: TARGETS → ChildCareClock → **General** → **Build** → change `1` to `2`, then archive again.

## Step 6 — Test on your iPhone with TestFlight (strongly recommended)
1. In App Store Connect → your app → **TestFlight** tab, your build appears.
2. Under **Internal Testing**, click **+**, create a group, add yourself.
3. Install the **TestFlight** app from the App Store on your iPhone, accept the invite, install Baby Care Clock.
4. Go through onboarding, log a few items, check a notification arrives (add one due a minute later), tap Done on the notification, add the widget to your Home Screen, and share a day from History.

## Step 7 — Fill in the store page
Everything to copy is in `AppStore/LISTING.md`.
1. App Store Connect → your app → **App Store** tab → **1.0 Prepare for Submission**.
2. **Screenshots**: drag the screenshots you saved (see LISTING.md) into the **iPhone 6.9" Display** box.
3. Paste **Promotional Text**, **Description**, **Keywords**, **Support URL**, **Copyright**.
4. **Build**: click **+** / Add Build and pick the build you uploaded.
5. **App Review Information**: untick "Sign-in required", add your contact details, paste the notes from LISTING.md.
6. **Version Release**: choose "Automatically release this version" (or manual if you want to pick the day).
7. Left sidebar → **App Information**: category **Health & Fitness**, content rights answer, and **Age Rating** → answer No/None to everything → 4+.
8. Left sidebar → **App Privacy**: paste your privacy policy URL, then **Get Started** → "No, we do not collect data" → **Publish**.
9. Left sidebar → **Pricing and Availability**: price **Free**, choose countries (all is fine).
10. Click **Save**, then **Add for Review** → **Submit to App Review**.

## Step 8 — Wait
- Status goes *Waiting for Review* → *In Review* → *Ready for Distribution* (usually 1–3 days).
- If Apple rejects it, they explain why in **App Review** messages. Read it, fix it, reply or resubmit. A first rejection is common and not a big deal.

---

### Updating the app later
1. Make your changes in Xcode.
2. TARGETS → ChildCareClock → **General**: raise **Version** (e.g. 1.0 → 1.1) and **Build** (e.g. 1 → 2).
3. Product → Archive → Distribute App (Step 5).
4. App Store Connect → **+ Version or Platform** → iOS → enter the new version, select the new build, write "What's New", submit.


---

### Note about free (Personal Team) signing
The app shares data with its widget through an **App Group** (`group.com.rajathverse.childcareclock`). Apple's free Personal Team cannot sign App Groups, so with a free team Xcode shows a signing error when you run on a real iPhone. You have two options:
- **Recommended:** join the paid Apple Developer Program (Step 1). Everything then signs automatically.
- **Testing before you enroll:** in **Signing & Capabilities**, remove **App Groups** from both the ChildCareClock and ChildCareClockWidget targets. The app works fully (it falls back to its own storage), but the widget will show "Open Baby Care Clock to get started". Put App Groups back before submitting.

The simulator does not need any of this. Just pick an iPhone simulator and press Run.
