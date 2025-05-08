<div align="center">
  <img src="frontend/src/assets/images/logo/interestnaut-logo.png" alt="Interestnaut Logo" width="200"/>
</div>

<div align="center">

[![GitHub release](https://img.shields.io/github/v/release/catlee993/interestnaut)](https://github.com/catlee993/interestnaut/releases)
[![License](https://img.shields.io/github/license/catlee993/interestnaut)](LICENSE)
[![Issues](https://img.shields.io/github/issues/catlee993/interestnaut)](https://github.com/catlee993/interestnaut/issues)

</div>

<div align="center">
  <img src="frontend/src/assets/video/interestnaut-demo.gif" alt="interestnaut demo" width="640"/>
  <br/>
  <sub>interestnaut demo</sub>
</div>

<div align="center">
  <strong><a href="https://github.com/catlee993/interestnaut/releases/latest">⬇️ Download the latest release</a></strong>
</div>

# Interestnaut

A multi-media discovery app that helps you find and track content across different media types: music, movies, TV shows, books, and games.

## Project Structure

The application is built using:
- **Go backend**: Handles API integrations, data processing, and business logic
- **Flutter frontend**: Provides the user interface for all platforms
- **FFI (Foreign Function Interface)**: Enables direct communication between Go and Flutter

```
├── cmd/interestnaut      # Main Go application code
├── internal/
│   ├── app/              # Backend application code
│   │   ├── bindings/     # API integrations for various media types
│   │   ├── creds/        # Credential management
│   │   ├── ffi/          # Foreign Function Interface code (Go side)
│   │   └── session/      # Session management
│   └── ui/
│       └── flutter/      # Flutter app for UI
├── scripts/              # Build and utility scripts
└── dist/                 # Distribution output (created by build script)
```

## Development Setup

### Prerequisites

- Go 1.17+
- Flutter 3.0+
- C compiler (for CGO)

### Running in Development Mode

Option 1: Launch the Go app which will start the Flutter UI:

```bash
go run cmd/interestnaut/main.go
```

Option 2: Run the Flutter app directly (requires the Go library to be built first):

```bash
# Build the shared library
go build -buildmode=c-shared -o libinterestnaut.dylib ./cmd/interestnaut/

# Run the Flutter app
cd internal/ui/flutter
flutter run
```

## Building for Production

Use the provided production build script:

```bash
./scripts/build_production.sh
```

This script will:
1. Build the Go binary executable
2. Build the Go shared library for FFI
3. Build the Flutter app in release mode
4. Package everything together for the current platform
5. Create a distribution package in the `dist/` directory

## Running the Production Build

After building, you can run the application:

### On macOS:
```bash
# From the dist/Interestnaut directory
./launch.sh
```

### On Linux:
```bash
# From the dist/Interestnaut directory
./launch.sh
```

### On Windows:
```bash
# From the dist/Interestnaut directory
launch.bat
```

## Deployment Model

The production deployment model uses the Go binary as the main executable, which:

1. Launches and manages the Flutter UI process
2. Provides a shared library for FFI communication
3. Handles all backend API calls and business logic

The Flutter UI communicates with the Go backend through FFI calls, without needing a separate network service.

## App Store Distribution

For app store distribution (macOS App Store, iOS App Store, etc.), additional steps are needed:

1. Code signing with appropriate developer certificates
2. Notarization (macOS)
3. Entitlements configuration
4. App store metadata preparation

Refer to the platform-specific documentation for detailed instructions on app store submission.

## Features

- View your saved media
- Search and add new media to your library
- Remove media from your library
- Preview track audio
- Add media to watch/read lists
- AI-powered media recommendations (music, movies, shows, vide games, and books)
- Multi-LLM support (OpenAI and Google Gemini)
- Integrates with Spotify for Music
- Integrates with TMDB for Movies and TV Shows
- Integrates with RAWG for Video Games
- Integrates with OpenLibrary for Books

## LLM Providers

Interestnaut supports multiple LLM providers for AI-powered recommendations:

- **OpenAI** (default): Uses the OpenAI GPT models for generating recommendations
  - OpenAI dev key requires paid-for credits, but responses tend to be better
- **Google Gemini**: Uses Google's Gemini models as an alternative
  - Gemini is currently free to use, so I recommend trying it out if you have an account

You can switch between providers in the Settings panel. The application dynamically uses the selected provider without requiring a restart.

### Setting Up LLM Providers

1. Click on the Settings icon in the app
2. Navigate to the Authentication tab
3. Enter your API key for the provider you want to use
   1. Note -- all authorization keys are stored in your OS's keychain using https://github.com/zalando/go-keyring

### Setting Up Media Providers

1. Create dev accounts with [RAWG](https://rawg.io/) and [TMDB](https://www.themoviedb.org/) to get your API keys
2. Navigate to the Settings tab in the app
3. Enter your API keys for RAWG and TMDB
   1. Note -- all authorization keys are stored in your OS's keychain using https://github.com/zalando/go-keyring
4. Spotify should request authorization at bootup if no token is found; this token will be saved in your OS's keychain
5. OpenLibrary does not require an API key, so if you have LLMs set up, you can start using it right away

## Development

1. Clone the repository
2. Run `wails dev` to start the development server

## Building

Run `wails build` to create a production build.

## Tech Stack

**Framework & Core Languages**
- [Wails](https://wails.io/) – Desktop app framework
- [Go](https://go.dev/) – Backend
- [React](https://react.dev/), [TypeScript](https://www.typescriptlang.org/), [MUI](https://mui.com/) – Frontend UI

**APIs & Integrations**
- [Spotify Web API](https://spotify.com) – Music metadata & playback
- [TMDB API](https://www.themoviedb.org/) – Movie & TV metadata
- [RAWG API](https://rawg.io/) – Video game metadata
- [OpenLibrary API](https://openlibrary.org/) – Book metadata

**LLM Providers**
- [OpenAI API](https://openai.com/) – GPT-powered recommendations
- [Gemini API](https://gemini.google.com/) – Google-powered recommendations

## License

Interestnaut is open source under the [MIT License](LICENSE).
You are free to use, share, and adapt the code and assets, provided you include attribution to the original author (cat lee).
