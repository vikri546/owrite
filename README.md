# owrite - News Reader App

<p align="center">
  <img src="assets/images/icon-app.png" alt="OWrite Logo" width="120"/>
</p>

A modern, feature-rich news reader application built with Flutter. owrite provides a seamless reading experience with AI-powered features, personalization options, and cross-platform support.

## 📱 Features

### Core Features

- **News Feed** - Browse latest news articles with infinite scroll
- **Article Reader** - Rich article viewing with HTML rendering support
- **Search** - Full-text search with category filtering
- **Bookmarks** - Save articles with custom groups/folders
- **Reading History** - Track your reading activity
- **Video Content** - Watch news videos and YouTube integration
- **Shorts Player** - Short-form video content support

### AI-Powered Features

- **Gemini AI Integration** - AI-powered content summarization and assistance
- **Text-to-Speech (TTS)** - Listen to articles with voice synthesis

### Personalization

- **Theme Support** - Light and dark mode with custom transitions
- **Multiple Font Families** - DMSans, CrimsonPro, Inter, Arimo, Domine, SourceSerif4, Bricolage Grotesque, Anton
- **Display Settings** - Customize font size, line height, and reading preferences
- **Language Support** - Multi-language localization

### Notifications

- **Push Notifications** - Stay updated with breaking news
- **Background Notifications** - Receive updates even when app is closed
- **Notification Scheduler** - Customizable notification preferences
- **Local Notifications** - In-app notification management

### User Features

- **User Authentication** - Login/Register with multiple methods (Native, Web, Cookie-based)
- **User Profiles** - Manage account and preferences
- **Subscription** - Premium content access
- **Feedback System** - Submit feedback with weekly limits

### Connectivity

- **Offline Support** - Cached content for offline reading
- **Location Services** - Location-based news and weather
- **Share Integration** - Share articles across apps
- **In-App Browser** - Open external links within the app

---

## 🛠️ Tech Stack

### Framework

| Technology | Version | Description                 |
| ---------- | ------- | --------------------------- |
| Flutter    | 3.6.0+  | Cross-platform UI framework |
| Dart SDK   | ^3.6.0  | Programming language        |

### Core Dependencies

#### State Management & Architecture

| Package    | Version | Purpose                   |
| ---------- | ------- | ------------------------- |
| `provider` | ^6.0.5  | State management solution |

#### Networking & API

| Package              | Version | Purpose                                |
| -------------------- | ------- | -------------------------------------- |
| `http`               | ^0.13.5 | HTTP client for API calls              |
| `dio`                | ^5.4.0  | Advanced HTTP client with interceptors |
| `cookie_jar`         | ^4.0.8  | Cookie persistence                     |
| `dio_cookie_manager` | ^3.1.1  | Cookie management for Dio              |

#### UI & Styling

| Package                | Version | Purpose                       |
| ---------------------- | ------- | ----------------------------- |
| `flutter_svg`          | ^2.0.9  | SVG rendering                 |
| `cached_network_image` | ^3.2.3  | Image caching and loading     |
| `cupertino_icons`      | ^1.0.8  | iOS-style icons               |
| `flutter_html`         | ^3.0.0  | HTML content rendering        |
| `flutter_html_video`   | ^3.0.0  | Video support in HTML content |

#### Storage & Persistence

| Package              | Version | Purpose                 |
| -------------------- | ------- | ----------------------- |
| `shared_preferences` | ^2.5.3  | Key-value local storage |
| `path_provider`      | ^2.1.1  | File system paths       |

#### Firebase & Analytics

| Package              | Version | Purpose                     |
| -------------------- | ------- | --------------------------- |
| `firebase_core`      | ^3.13.0 | Firebase core functionality |
| `firebase_analytics` | ^11.6.0 | Analytics tracking          |

#### Notifications

| Package                       | Version | Purpose                    |
| ----------------------------- | ------- | -------------------------- |
| `flutter_local_notifications` | ^17.2.1 | Local push notifications   |
| `workmanager`                 | ^0.9.0  | Background task scheduling |

#### WebView & Browser

| Package                    | Version | Purpose                    |
| -------------------------- | ------- | -------------------------- |
| `flutter_inappwebview`     | ^6.0.0  | In-app browser and WebView |
| `flutter_inappwebview_web` | ^1.0.9  | Web platform support       |
| `webview_cookie_manager`   | ^2.0.6  | WebView cookie handling    |
| `url_launcher`             | ^6.3.2  | Open URLs in browser       |

#### Media & Audio

| Package                  | Version | Purpose               |
| ------------------------ | ------- | --------------------- |
| `flutter_tts`            | ^3.8.5  | Text-to-speech engine |
| `audioplayers`           | ^6.0.0  | Audio playback        |
| `youtube_player_flutter` | ^9.1.3  | YouTube video player  |

#### Location Services

| Package      | Version | Purpose                        |
| ------------ | ------- | ------------------------------ |
| `geolocator` | ^11.1.0 | GPS and location access        |
| `geocoding`  | ^2.1.1  | Address/coordinates conversion |

#### Utilities

| Package               | Version | Purpose                                  |
| --------------------- | ------- | ---------------------------------------- |
| `intl`                | ^0.20.2 | Internationalization and date formatting |
| `share_plus`          | ^10.0.1 | Share content to other apps              |
| `package_info_plus`   | ^8.2.8  | App version and package info             |
| `connectivity_plus`   | ^6.1.2  | Network connectivity detection           |
| `android_intent_plus` | ^4.0.3  | Android intent handling                  |
| `permission_handler`  | ^11.3.1 | Runtime permissions                      |
| `html_unescape`       | ^2.0.0  | HTML entity decoding                     |
| `html`                | ^0.15.5 | HTML parsing                             |
| `flutter_dotenv`      | ^5.1.0  | Environment variables                    |

### Dev Dependencies

| Package                   | Version | Purpose              |
| ------------------------- | ------- | -------------------- |
| `flutter_test`            | SDK     | Testing framework    |
| `flutter_lints`           | ^5.0.0  | Code quality linting |
| `mockito`                 | ^5.3.2  | Mocking for tests    |
| `build_runner`            | ^2.3.3  | Code generation      |
| `flutter_launcher_icons`  | ^0.13.1 | App icon generation  |
| `change_app_package_name` | ^1.1.0  | Package name utility |

---

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── article.dart          # Article model
│   └── video.dart            # Video model
├── providers/                # State providers
│   ├── article_provider.dart # Article state management
│   ├── language_provider.dart# Language settings
│   ├── theme_provider.dart   # Theme management
│   └── video_provider.dart   # Video state management
├── repositories/             # Data repositories
├── screens/                  # UI screens (29 screens)
│   ├── home_screen.dart      # Main home screen
│   ├── article_detail_screen.dart # Article reader
│   ├── search_screen.dart    # Search functionality
│   ├── bookmark_screen.dart  # Saved articles
│   ├── history_screen.dart   # Reading history
│   ├── settings_screen.dart  # App settings
│   ├── notifications_screen.dart # Notifications
│   └── ... (22 more screens)
├── services/                 # Business logic services (14 services)
│   ├── api_service.dart      # API communication
│   ├── gemini_service.dart   # AI integration
│   ├── bookmark_service.dart # Bookmark management
│   ├── notification_service.dart # Notifications
│   └── ... (10 more services)
├── utils/                    # Utility classes
│   ├── theme_config.dart     # Theme configuration
│   ├── auth_service.dart     # Authentication
│   ├── custom_page_transitions.dart # Page animations
│   └── ... (5 more utilities)
└── widgets/                  # Reusable widgets (13 widgets)
    ├── article_card.dart     # Article card component
    ├── video_card.dart       # Video card component
    ├── shimmer_loading.dart  # Loading animations
    └── ... (10 more widgets)
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.6.0 or higher
- Dart SDK 3.6.0 or higher
- Android Studio / VS Code
- Xcode (for iOS development)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/owrite.git
   cd owrite
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Setup environment variables**

   Create a `.env` file in the root directory:

   ```env
   API_BASE_URL=your_api_url
   GEMINI_API_KEY=your_gemini_api_key
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Build for Production

**Android:**

```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

**iOS:**

```bash
flutter build ios --release
```

**Web:**

```bash
flutter build web --release
```

---

## 🎨 Theming

The app supports both light and dark themes with smooth transitions. Custom fonts are included:

- **DMSans** - Primary UI font
- **CrimsonPro** - Serif reading font
- **Inter** - Secondary UI font
- **Arimo** - Alternative sans-serif
- **Domine** - Serif heading font
- **SourceSerif4** - Article body font
- **Bricolage Grotesque** - Display font
- **Anton** - Bold display font

---

## 📱 Supported Platforms

| Platform | Status    |
| -------- | --------- |
| Android  | Supported |
| iOS      | Not Yet   |
| Web      | Supported |
| Windows  | Supported |
| macOS    | Not Yet   |
| Linux    | Supported |

---

## 📄 License

This project is proprietary software. All rights reserved.

---

## 📞 Contact

For support or inquiries, please use the in-app feedback feature or contact the development team.

---

**Version:** 7.1.3+9
