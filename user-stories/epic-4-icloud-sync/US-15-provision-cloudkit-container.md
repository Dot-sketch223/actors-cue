# US-15 — Provision the CloudKit container in the Developer Portal

**Epic:** iCloud Sync

**Type:** Manual task (no code changes required)

## User Story
As a developer, I want the CloudKit container registered and the App ID configured so that iCloud sync activates on real devices.

## Steps

### 1. Create the CloudKit container
1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com)
2. Sign in with your Apple ID
3. Click **Create a New Container**
4. Enter the identifier: `iCloud.com.actorscue.app`

### 2. Enable iCloud on the App ID
1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Find the App ID `com.actorscue.app` (create it first if it doesn't exist)
3. Click the App ID → **Edit**
4. Under **Capabilities**, enable **iCloud**
5. Select **CloudKit**
6. Associate it with the container `iCloud.com.actorscue.app`
7. Save

### 3. Regenerate your provisioning profile
1. In Certificates, Identifiers & Profiles → **Profiles**
2. Find the profile for `com.actorscue.app` and regenerate it (or let Xcode manage it automatically if using Automatic signing)
3. If using manual signing, download and install the new profile in Xcode

### 4. Verify in Xcode
1. Open `ActorsCue.xcodeproj`
2. Select the **ActorsCue** target → **Signing & Capabilities**
3. Confirm the **iCloud** capability is present with CloudKit checked and `iCloud.com.actorscue.app` listed
4. Build and run on a real device signed into iCloud
5. Import a script — it should appear on a second device within a few seconds

## Acceptance Criteria
- `iCloud.com.actorscue.app` container exists in CloudKit Dashboard
- App ID `com.actorscue.app` has iCloud + CloudKit enabled and linked to the container
- App builds without signing errors
- A script imported on one device syncs to a second device automatically
