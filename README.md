# Linea

> Minimalist, line-paced reading designed to eliminate distraction, boost focus and help in increasing reading speed.

Linea is a focused reading application that parses PDF and EPUB documents into structured, line-by-line text blocks. By delivering text sequentially at user-controlled time intervals, Linea helps readers maintain focus, reduce eye fatigue, and maintain a steady reading rhythm.

---

## Core Concept: Rapid Serial Visual Presentation (RSVP)

Linea utilizes **Rapid Serial Visual Presentation (RSVP)** and **Paced Reading** techniques. Traditional reading requires continuous horizontal scanning and line-tracking, which often leads to distraction and regression (re-reading lines).

Linea extracts the text from your documents behind the scenes, indexing it by page and line, and presents it sequentially at your custom pace — ranging anywhere from 2 to 6 seconds per line.

> **Note:** Linea is **not ideal** for complex comprehension, deep studying, or reviewing dense information.

---

## Key Features

- **Document Extraction:** Automatic line and page parsing for PDF and EPUB formats.
- **Customizable Interval Engine:** Adjustable line-switch speeds tailored to individual reading rates.
- **Distraction-Free Interface:** Pure text presentation free from page clutter, columns, and marginalia.
- **Theme Customization:** Choose from multiple color palettes to suit your reading environment.
- **Dark Mode:** Seamlessly toggle between light and dark themes.
- **Fullscreen Reading:** Immersive fullscreen mode for an uninterrupted reading experience.
- **Cross-Platform Layouts:** Optimized, responsive design for desktop and mobile reading.
- **Progress Tracking:** Instant line-level position retention across sessions.

---

## Application Showcase

### Desktop

<div align="center">

**Dashboard**

<img src="assets/screenshots/dashboard.gif" alt="Linea Desktop Dashboard" width="700"/>

**Reader**

<img src="assets/screenshots/reader.gif" alt="Linea Desktop Reader" width="700"/>

</div>

### Mobile

<div align="center">

<table>
  <tr>
    <td align="center"><b>Dashboard</b></td>
    <td align="center"><b>Reader</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/mobile_dashboard.gif" alt="Linea Mobile Dashboard" width="280"/></td>
    <td><img src="assets/screenshots/mobile_reader.jpg" alt="Linea Mobile Reader" width="280"/></td>
  </tr>
</table>

**Fullscreen Reader**

<img src="assets/screenshots/reader_mobile_fullscreen.jpg" alt="Linea Mobile Fullscreen Reader" width="700"/>

</div>



---

## Download & Installation

Installer and pre-built binaries for desktop and Android are available on the official releases page.

[**Get Latest Release →**](https://github.com/Ankit-692/linea/releases)

### Supported Platforms

| Platform | Support                  |
|----------|--------------------------|
| macOS    | ✅                       |
| Windows  | ✅                       |
| Linux    | ✅                       |
| Android  | ✅                       |
| iOS      | 🔧 Manual build only    |

### Note for macOS Users

Since Linea isn't notarized by Apple (no paid developer account), macOS will block it on first open.

**To run it:**

- Right-click the **app → Open → click Open again** in the dialog, **OR**
- Open Terminal and run:

```bash
xattr -cr /Applications/Linea.app
```

### Note for iOS Users

No pre-built IPA is distributed since distributing iOS apps outside the App Store without a paid Apple Developer account either requires self-signing (which expires every 7 days with a free account) or won't install at all.

If you want to run Linea on iOS, you can **build and sign it yourself**:

1. Clone the repository and open it in Xcode.
2. In **Signing & Capabilities**, select your own Apple ID as the development team.
3. Connect your device and hit **Run** — Xcode will sign and install it for you.

> **Note:** Free Apple ID certificates expire every 7 days and you'll need to re-install. A paid Apple Developer account removes this limitation.

---

## How It Works

1. **Upload:** Open any standard `.pdf` or `.epub` document within Linea.
2. **Extraction:** The internal parser breaks down the raw content into structured line indices.
3. **Pacing:** Select your preferred interval timing (e.g., 3.5 seconds per line).
4. **Read:** Press play to begin auto-paced reading without manual scrolling.

---

## 🛠 Developer Guide — Building from Source

> This section is for contributors or anyone who wants to make changes to the source and build their own version. If you just want to use Linea, grab a pre-built binary from the [Releases](https://github.com/Ankit-692/linea/releases) page instead.

### Prerequisites

| Requirement | Version |
|---|---|
| Flutter SDK | `≥ 3.12.2` |
| Dart SDK | `≥ 3.12.2` (bundled with Flutter) |
| Xcode *(iOS/macOS only)* | Latest stable |
| Android Studio / SDK *(Android only)* | Latest stable |
| Visual Studio Build Tools *(Windows only)* | With C++ workload |

> Make sure `flutter doctor` reports no critical issues before building.

### 1. Clone the Repository

```bash
git clone https://github.com/Ankit-692/linea.git
cd linea
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run in Development

```bash
# Desktop
flutter run -d macos      # macOS
flutter run -d windows    # Windows
flutter run -d linux      # Linux

# Mobile
flutter run -d android
```

> For desktop, ensure the appropriate platform is enabled:
> ```bash
> flutter config --enable-macos-desktop
> flutter config --enable-windows-desktop
> flutter config --enable-linux-desktop
> ```

### 4. Build Your Own Binary

Once you've made your changes, build a binary for your target platform:

```bash
# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release

# Android (APK)
flutter build apk --release

# Android (App Bundle)
flutter build appbundle --release
```

Built outputs land in the `build/` directory under the respective platform folder.

#### Platform Signing Notes

| Platform | What to expect |
|---|---|
| **Linux** | No signing needed. Runs as-is. |
| **Windows** | May show a SmartScreen warning — click **More info → Run anyway**. Normal for unsigned builds. |
| **Android** | Flutter auto-signs the APK with a debug key. Enable **Install from unknown sources** on the device. |
| **macOS** | Gatekeeper will block the app. Run `xattr -cr /path/to/Linea.app` once to bypass it. |

### Project Structure

```
lib/
├── main.dart               # App entry point
├── core/
│   ├── state/              # Global state management (Provider)
│   ├── theme/              # Color palettes and theme configuration
│   ├── utils/              # Shared utilities and helpers
│   └── widgets/            # Reusable UI components
└── features/
    ├── onboarding/         # Document import and initial setup
    ├── dashboard/          # Library and document management
    └── reader/             # RSVP reader engine and playback UI
```

---

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for details.

