<p align="center">
  <img src="assets/images/icon-app.png" alt="owrite" width="100"/>
</p>

<h1 align="center">owrite</h1>

<p align="center">
  <strong>Modern news reader app built with Flutter</strong><br/>
  AI-powered features · Cross-platform · Personalized experience
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.6.0+-02569B?logo=flutter&logoColor=white"/>
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.6.0+-0175C2?logo=dart&logoColor=white"/>
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-brightgreen"/>
  <img alt="License" src="https://img.shields.io/badge/License-Proprietary-red"/>
</p>

---

## ✨ Features

| Category            | Features                                                                  |
| ------------------- | ------------------------------------------------------------------------- |
| **News Feed**       | Infinite scroll · Category filtering · Full-text search · Reading history |
| **Article Reader**  | HTML rendering · Text-to-Speech · AI summarization (Gemini)               |
| **Video**           | YouTube integration · Shorts player · Trending videos                     |
| **Bookmarks**       | Save articles · Custom groups/folders                                     |
| **Notifications**   | Push notifications · Background updates · Scheduled alerts                |
| **Personalization** | Light/Dark theme · 8 font families · Display settings · Multi-language    |
| **Connectivity**    | Offline cache · Location services · Share integration · In-app browser    |
| **Authentication**  | Login/Register · Cookie-based auth · User profiles · Subscription         |

---

## 🛠️ Tech Stack

### Framework

| Technology | Version | Purpose                     |
| ---------- | ------- | --------------------------- |
| Flutter    | 3.6.0+  | Cross-platform UI framework |
| Dart SDK   | ^3.6.0  | Programming language        |

### Dependencies

<details>
<summary><strong>State Management & Architecture</strong></summary>

| Package    | Version | Purpose          |
| ---------- | ------- | ---------------- |
| `provider` | ^6.0.5  | State management |

</details>

<details>
<summary><strong>Networking & API</strong></summary>

| Package              | Version | Purpose                         |
| -------------------- | ------- | ------------------------------- |
| `http`               | ^0.13.5 | HTTP client                     |
| `dio`                | ^5.4.0  | Advanced HTTP with interceptors |
| `cookie_jar`         | ^4.0.8  | Cookie persistence              |
| `dio_cookie_manager` | ^3.1.1  | Cookie management for Dio       |

</details>

<details>
<summary><strong>UI & Styling</strong></summary>

| Package                | Version | Purpose                |
| ---------------------- | ------- | ---------------------- |
| `flutter_svg`          | ^2.0.9  | SVG rendering          |
| `cached_network_image` | ^3.2.3  | Image caching          |
| `cupertino_icons`      | ^1.0.8  | iOS-style icons        |
| `flutter_html`         | ^3.0.0  | HTML content rendering |
| `flutter_html_video`   | ^3.0.0  | Video in HTML content  |

</details>

<details>
<summary><strong>Storage & Persistence</strong></summary>

| Package              | Version | Purpose                 |
| -------------------- | ------- | ----------------------- |
| `shared_preferences` | ^2.5.3  | Key-value local storage |
| `path_provider`      | ^2.1.1  | File system paths       |

</details>

<details>
<summary><strong>Firebase & Analytics</strong></summary>

| Package              | Version | Purpose            |
| -------------------- | ------- | ------------------ |
| `firebase_core`      | ^3.13.0 | Firebase core      |
| `firebase_analytics` | ^11.6.0 | Analytics tracking |

</details>

<details>
<summary><strong>Notifications</strong></summary>

| Package                       | Version | Purpose                    |
| ----------------------------- | ------- | -------------------------- |
| `flutter_local_notifications` | ^17.2.1 | Local push notifications   |
| `workmanager`                 | ^0.9.0  | Background task scheduling |

</details>

<details>
<summary><strong>WebView & Browser</strong></summary>

| Package                    | Version | Purpose              |
| -------------------------- | ------- | -------------------- |
| `flutter_inappwebview`     | ^6.0.0  | In-app browser       |
| `flutter_inappwebview_web` | ^1.0.9  | Web platform support |
| `webview_cookie_manager`   | ^2.0.6  | WebView cookies      |
| `url_launcher`             | ^6.3.2  | Open external URLs   |

</details>

<details>
<summary><strong>Media & Audio</strong></summary>

| Package                  | Version | Purpose        |
| ------------------------ | ------- | -------------- |
| `flutter_tts`            | ^3.8.5  | Text-to-speech |
| `audioplayers`           | ^6.0.0  | Audio playback |
| `youtube_player_flutter` | ^9.1.3  | YouTube player |

</details>

<details>
<summary><strong>Location Services</strong></summary>

| Package      | Version | Purpose                        |
| ------------ | ------- | ------------------------------ |
| `geolocator` | ^11.1.0 | GPS and location               |
| `geocoding`  | ^2.1.1  | Address/coordinates conversion |

</details>

<details>
<summary><strong>Utilities</strong></summary>

| Package               | Version | Purpose                  |
| --------------------- | ------- | ------------------------ |
| `intl`                | ^0.20.2 | i18n and date formatting |
| `share_plus`          | ^10.0.1 | Share content            |
| `package_info_plus`   | ^8.2.8  | App version info         |
| `connectivity_plus`   | ^6.1.2  | Network detection        |
| `android_intent_plus` | ^4.0.3  | Android intents          |
| `permission_handler`  | ^11.3.1 | Runtime permissions      |
| `html_unescape`       | ^2.0.0  | HTML entity decoding     |
| `html`                | ^0.15.5 | HTML parsing             |
| `flutter_dotenv`      | ^5.1.0  | Environment variables    |

</details>

<details>
<summary><strong>Dev Dependencies</strong></summary>

| Package                   | Version | Purpose              |
| ------------------------- | ------- | -------------------- |
| `flutter_test`            | SDK     | Testing framework    |
| `flutter_lints`           | ^5.0.0  | Code quality         |
| `mockito`                 | ^5.3.2  | Mocking for tests    |
| `build_runner`            | ^2.3.3  | Code generation      |
| `flutter_launcher_icons`  | ^0.13.1 | App icon generation  |
| `change_app_package_name` | ^1.1.0  | Package name utility |

</details>

---

## 📁 Project Structure

```
lib/
├── main.dart                     # App Entry Point
├── models/                       # Data Models
│   ├── article.dart              #   Article Model
│   └── video.dart                #   Video Model
├── providers/                    # State Management
│   ├── article_provider.dart     #   Article Provider
│   ├── language_provider.dart    #   Language Settings
│   ├── theme_provider.dart       #   Theme Provider
│   └── video_provider.dart       #   Video Provider
├── repositories/                 # Data Repositories
├── screens/                      # UI Screens (30)
│   ├── home_screen.dart          #   Home Screen
│   ├── article_detail_screen.dart#   Article Reader
│   ├── search_screen.dart        #   Search
│   ├── bookmark_screen.dart      #   Bookmarks
│   ├── history_screen.dart       #   Reading History
│   ├── settings_screen.dart      #   Settings
│   ├── notifications_screen.dart #   Notifications
│   └── ...                       #   +23 more screens
├── services/                     # Business Logic (14)
│   ├── api_service.dart          #   API Connect
│   ├── youtube_service.dart      #   YouTube Integration
│   ├── gemini_service.dart       #   AI Summarization
│   ├── notification_service.dart #   Push Notifications
│   ├── reading_tracker_service.dart # Reading Tracker
│   ├── bookmark_service.dart     #   Bookmark Manager
│   └── ...                       #   +8 more services
├── utils/                        # Utilities (8)
│   ├── theme_config.dart         #   Theme Config
│   ├── auth_service.dart         #   Auth Service
│   ├── custom_page_transitions.dart # Page Transitions
│   └── ...                       #   +5 more utils
└── widgets/                      # Reusable Widgets (13)
    ├── article_card.dart         #   Article Card
    ├── video_card.dart           #   Video Card
    ├── shimmer_loading.dart      #   Loading Skeleton
    └── ...                       #   +10 more widgets
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.6.0+
- Dart SDK 3.6.0+
- Android Studio / VS Code
- Xcode (for iOS)

### Installation

```bash
# Clone repository
git clone https://github.com/yourusername/owrite.git
cd owrite

# Install dependencies
flutter pub get

# Create .env in root directory
cat > .env << EOF
API_BASE_URL=your_api_url
GEMINI_API_KEY=your_gemini_api_key
YOUTUBE_API_KEY=your_youtube_api_key
EOF

# Run
flutter run
```

### Build for Production

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## 🍎 iOS Build Guide

### Prerequisites

| Requirement            | Details                                 |
| ---------------------- | --------------------------------------- |
| **macOS**              | Required (Xcode only runs on macOS)     |
| **Xcode**              | 15.0+ from Mac App Store                |
| **CocoaPods**          | iOS dependency manager                  |
| **Apple Developer ID** | Free for simulator, $99/year for device |
| **Flutter SDK**        | 3.6.0+                                  |

### Step 1 — Install CocoaPods

```bash
sudo gem install cocoapods
# or: brew install cocoapods
```

### Step 2 — Firebase iOS Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your Firebase project → **Add App** → **iOS**
3. Enter Bundle ID: `com.medias.owrite`
4. Download `GoogleService-Info.plist`
5. Place it in `ios/Runner/GoogleService-Info.plist`

> ⚠️ **Important**: Without `GoogleService-Info.plist`, the app will crash on launch.

### Step 3 — Install iOS Dependencies

```bash
flutter pub get
cd ios && pod install && cd ..
```

> If `pod install` fails: `cd ios && pod repo update && pod install --repo-update && cd ..`

### Step 4 — Code Signing (Xcode)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** → **Signing & Capabilities**
3. Enable **Automatically manage signing**
4. Select your **Team**

### Step 5 — Build & Run

```bash
# Simulator
flutter run -d "iPhone 16 Pro"

# Device (debug)
flutter run -d <device-id>

# Release IPA
flutter build ipa --release
```

### Step 6 — App Store Submission (Optional)

1. Xcode → **Product** → **Archive**
2. **Window** → **Organizer** → **Distribute App**
3. Submit via [App Store Connect](https://appstoreconnect.apple.com/)

### iOS Notes

| Topic            | Details                                                          |
| ---------------- | ---------------------------------------------------------------- |
| Notifications    | Uses `UNUserNotificationCenter`, permission requested at runtime |
| Background Fetch | Configured via `UIBackgroundModes` in `Info.plist`               |
| Location         | Usage description strings already configured in `Info.plist`     |
| Browser          | Falls back to `url_launcher` (no Android intent-based chooser)   |
| TTS              | Uses native `AVSpeechSynthesizer`                                |

### Troubleshooting

| Issue                              | Solution                                                      |
| ---------------------------------- | ------------------------------------------------------------- |
| `pod install` fails                | Run `pod repo update` then retry                              |
| Signing error                      | Add Apple Developer account in Xcode → Preferences → Accounts |
| Missing `GoogleService-Info.plist` | Download from Firebase Console → `ios/Runner/`                |
| Build fails on Apple Silicon       | `arch -x86_64 pod install` or install ffi gem                 |
| Deployment target error            | Set iOS 13.0+ in Xcode project settings                       |

---

## 🎨 Theming

Light and dark themes with smooth transitions. Included fonts:

| Font                    | Usage                  |
| ----------------------- | ---------------------- |
| **DMSans**              | Primary UI             |
| **Inter**               | Secondary UI           |
| **CrimsonPro**          | Serif reading          |
| **Arimo**               | Alternative sans-serif |
| **Domine**              | Serif headings         |
| **SourceSerif4**        | Article body           |
| **Bricolage Grotesque** | Display                |
| **Anton**               | Bold display           |

---

## 📱 Platform Support

| Platform | Status       |
| -------- | ------------ |
| Android  | ✅ Supported |
| iOS      | ✅ Supported |
| Web      | ✅ Supported |
| Windows  | ✅ Supported |
| Linux    | ✅ Supported |
| macOS    | 🔜 Planned   |

---

## 📄 License

This project is proprietary software. All rights reserved.

---

## 📞 Contact

For support or inquiries, use the in-app feedback feature or contact the development team.

---

<p align="center"><strong>owrite</strong> · v1.0.5+3</p>
