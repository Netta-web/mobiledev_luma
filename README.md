# Luma

> A private memory documentation and sharing app built with Flutter.

Luma lets you capture moments tied to events — add photos, videos, notes, moods, and locations — then share them privately with contacts or via public share links, with full offline support.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Project Structure](#project-structure)
- [Deep Linking](#deep-linking)
- [Building for Release](#building-for-release)
- [Known Limitations](#known-limitations)

---

## Features

**Events & Memories**
- Create events with title, description, category, date range, and location
- Attach multiple photos and videos to a memory entry
- Add notes, mood tags, and GPS-resolved location names
- View memories on an interactive map (Google Maps)
- Full offline support — read and create while disconnected, sync when back online

**Sharing**
- Share memories privately with contacts by email (stored securely per recipient)
- Generate a public share link (`luma://s/{id}`) — no Luma account required to view
- Control download permissions per link
- Revoke access at any time
- Tap a share link on any Android device with Luma installed to open it directly

**Inbox**
- "Shared with me" screen streams memories others have shared with you in real time

**Profiles & Auth**
- Email/password sign-up, login, and password reset
- Profile photo upload and display name management

**Notifications**
- Firebase Cloud Messaging (FCM) push notifications
- Local notifications for in-app share confirmations

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI framework | Flutter (Material 3) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| File storage | Supabase Storage |
| Push notifications | Firebase Cloud Messaging |
| Local cache | Hive |
| State management | Provider |
| Maps | Google Maps Flutter |
| Deep links | app_links |
| Sharing | share_plus, url_launcher |
| Location | geolocator, geocoding |
| Contacts | flutter_contacts |

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.0.0`
- Android SDK with API level 23 or higher
- A [Firebase project](https://console.firebase.google.com) with Authentication and Firestore enabled
- A [Supabase project](https://supabase.com) with `memories` and `avatars` storage buckets created
- A [Google Maps API key](https://console.cloud.google.com) with the **Maps SDK for Android** enabled

---

## Getting Started

### 1. Clone the repository

```bash
git clone <repo-url>
cd my_luma
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

If you are connecting to your own Firebase project, run:

```bash
flutterfire configure
```

This regenerates `lib/firebase_options.dart` with your project's credentials.

Alternatively, edit `lib/firebase_options.dart` directly with values from your Firebase project settings.

### 4. Configure Supabase

Open `lib/config/supabase_config.dart` and replace the placeholders:

```dart
class SupabaseConfig {
  static const String url     = 'https://<your-project>.supabase.co';
  static const String anonKey = '<your-anon-key>';
}
```

In your Supabase dashboard, create two public storage buckets:
- `memories` — for memory photos and videos
- `avatars` — for user profile photos

### 5. Add your Google Maps API key

Open `android/app/src/main/AndroidManifest.xml` and replace the placeholder on the `geo.API_KEY` meta-data entry:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

### 6. Run the app

```bash
flutter run
```

---

## Configuration

### Required configuration checklist

| Item | File | Status |
|---|---|---|
| Firebase options | `lib/firebase_options.dart` | Must match your Firebase project |
| Supabase URL + key | `lib/config/supabase_config.dart` | Must match your Supabase project |
| Google Maps API key | `android/app/src/main/AndroidManifest.xml` | Required for map features |
| Supabase buckets | Supabase dashboard | `memories` and `avatars` buckets must exist |

### Hive model generation

If you add or modify Hive data models, regenerate the adapter files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Project Structure

```
lib/
├── main.dart                        # App entry point, Firebase/Supabase/Hive init
├── firebase_options.dart            # Firebase project configuration
├── config/
│   └── supabase_config.dart         # Supabase URL and anon key
├── theme/
│   └── app_theme.dart               # Light/dark themes, colours, typography
├── providers/
│   ├── auth_provider.dart           # Authentication state
│   ├── event_provider.dart          # Event list state + Firestore listener
│   └── memory_provider.dart         # Memory list state
├── services/
│   ├── auth_service.dart            # Firebase Auth operations
│   ├── firestore_service.dart       # Firestore CRUD
│   ├── storage_service.dart         # Supabase Storage uploads/downloads
│   ├── hive_service.dart            # Hive box management
│   ├── location_service.dart        # GPS acquisition
│   ├── notification_service.dart    # FCM + local notifications
│   ├── sharing_service.dart         # Email-based memory sharing
│   └── share_link_service.dart      # Public share link management
├── models/
│   ├── user_model.dart
│   ├── event_model.dart
│   ├── memory_entry_model.dart
│   ├── shared_memory_model.dart
│   └── share_link_model.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart         # Dashboard, event list, deep link handler
│   ├── events/
│   │   ├── create_event_screen.dart
│   │   └── event_detail_screen.dart
│   ├── memories/
│   │   ├── add_memory_screen.dart
│   │   ├── memory_detail_screen.dart
│   │   └── memory_map_screen.dart
│   ├── profile/
│   │   └── profile_screen.dart
│   └── shared/
│       ├── shared_with_me_screen.dart
│       └── share_link_screen.dart   # Public share link viewer (no auth required)
└── widgets/
    ├── event_card.dart
    └── memory_tile.dart
```

---

## Deep Linking

Luma uses the custom URI scheme `luma://s/{linkId}` for shareable memory links.

When a user on Android taps a `luma://s/…` link (in SMS, WhatsApp, email, etc.) the OS opens the app directly and navigates to the share link screen.

The intent filter is registered in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="luma" android:host="s"/>
</intent-filter>
```

Recipients who do not have Luma installed can still open any link manually: tap the link icon on the home screen, paste the full `luma://s/…` URL or just the link code, and tap **Open**.

---

## Building for Release

### Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (Google Play)

```bash
flutter build appbundle --release
```

Before publishing, configure a release signing key in `android/app/build.gradle.kts`. See the [Flutter Android deployment guide](https://docs.flutter.dev/deployment/android) for instructions.

---

## Known Limitations

- **Android only** — iOS configuration is not included in this version.
- **Custom URI scheme** — Share links only auto-open on devices with Luma installed. There is no web fallback for recipients without the app.
- **Google Maps** — Map features are non-functional until a valid Maps SDK API key is provided.
- **Release signing** — The current Gradle config uses the debug keystore for release builds. Replace it with a production keystore before distributing.
