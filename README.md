# Chat Application

A Flutter real-time messaging app built with Firebase, Riverpod, Supabase Storage, and Firebase Cloud Messaging.

The app supports email authentication, unique usernames, direct chats, group chats, online presence, typing indicators, media/file attachments, unread counts, read receipts, and push notifications.

## Features

- Email/password sign up and sign in with Firebase Authentication
- Unique `@username` reservation and username-based user search
- One-to-one chats with deterministic chat IDs
- Group chat creation with member search and optional group avatar
- Real-time message streams from Cloud Firestore
- Online/offline presence and typing indicators with Firebase Realtime Database
- Text, image, video, and file messages
- Attachment upload through Supabase Storage
- Emoji picker in the message composer
- Unread counters and read receipts
- Local and remote push notifications using FCM and Firebase Functions
- Light/dark theme toggle

## Tech Stack

- Flutter and Dart
- Flutter Riverpod for state management
- Firebase Authentication
- Cloud Firestore
- Firebase Realtime Database
- Firebase Cloud Messaging
- Firebase Cloud Functions, TypeScript, Node.js 20
- Supabase Storage for chat attachments and group avatars
- `file_picker`, `emoji_picker_flutter`, `flutter_local_notifications`, `lottie`, and `url_launcher`

## Project Structure

```text
lib/
  config/          App configuration and runtime defines
  models/          User, Chat, Message, and presence models
  providers/       Riverpod providers and controllers
  repositories/    Firebase and Supabase data access
  screens/         Auth, chat list, chat detail, group creation, profile
  theme/           App theme definitions
  utils/           Formatters, navigation, push/local notification services
  widgets/         Reusable chat UI components

functions/
  src/index.ts     Firestore trigger that sends push notifications

assets/
  animations/      Lottie animation assets

firestore.rules    Firestore security rules
database.rules.json
firestore.indexes.json
firebase.json
```

## Prerequisites

- Flutter SDK compatible with Dart `^3.11.4`
- Firebase CLI
- Node.js 20 for Cloud Functions
- A Firebase project with:
  - Authentication enabled for Email/Password
  - Cloud Firestore enabled
  - Realtime Database enabled
  - Cloud Messaging enabled
  - Cloud Functions enabled
- A Supabase project with a public/private storage bucket named `chat-media`, depending on your storage policies

## Getting Started

1. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

2. Install Cloud Functions dependencies:

   ```bash
   npm --prefix functions install
   ```

3. Configure Firebase for your project if you are not using the checked-in Firebase app configuration:

   ```bash
   flutterfire configure
   ```

   This regenerates `lib/firebase_options.dart` and platform Firebase files such as `android/app/google-services.json`.

4. Configure Supabase Storage.

   The app reads Supabase values from Dart defines. The repository includes defaults in `lib/config/app_config.dart`, but for your own project you should pass your project URL and anon key at runtime:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=your-supabase-url \
     --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key
   ```

5. Run the app:

   ```bash
   flutter run
   ```

## Firebase Deployment

Deploy Firestore rules, Firestore indexes, Realtime Database rules, and Cloud Functions:

```bash
firebase deploy --only firestore:rules,firestore:indexes,database,functions
```

The Firebase Functions predeploy hook in `firebase.json` installs dependencies and builds the TypeScript source before deployment.

## Cloud Functions

The function in `functions/src/index.ts` listens for new documents under:

```text
chats/{chatId}/messages/{messageId}
```

When a non-system message is created, it:

- Loads the chat members
- Excludes the sender
- Reads each recipient's `notificationTokens`
- Sends an FCM notification with chat metadata
- Removes invalid FCM tokens from the user document

Useful commands:

```bash
npm --prefix functions run build
npm --prefix functions run lint
npm --prefix functions run serve
npm --prefix functions run deploy
```

## Data Model

Main Firestore collections:

- `users/{uid}`: profile, username, online snapshot, notification tokens
- `usernames/{username}`: username reservation mapped to a Firebase Auth UID
- `chats/{chatId}`: chat metadata, members, last message, unread counts
- `chats/{chatId}/messages/{messageId}`: message content and attachment metadata
- `callInvitations/{callId}`: rules are present for future call invitation support

Realtime Database paths:

- `status/{uid}`: online/offline presence and last changed timestamp
- `typing/{chatId}/{uid}`: transient typing state

Supabase Storage:

- `chat-media/{chatId}/{senderId}/...`: message attachments
- `chat-media/group-avatars/{ownerId}/...`: group avatar uploads

## Quality Checks

Run Flutter analysis and tests:

```bash
flutter analyze
flutter test
```

Build Cloud Functions:

```bash
npm --prefix functions run build
```

## Platform Notes

- Firebase is configured for Android, iOS, macOS, web, and Windows in `lib/firebase_options.dart`.
- Linux platform files exist, but Firebase options are not configured for Linux yet. Run `flutterfire configure` again if Linux support is needed.
- Android already declares permissions for internet access, notifications, camera, audio, and related capabilities.
- Attachments require Supabase Storage to be reachable and correctly authorized by your bucket policies.
