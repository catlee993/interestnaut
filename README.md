# Interestnaut

A desktop application for managing your favorite media and getting AI-powered recommendations. Built with Wails, Go, and React.

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

- [Wails](https://wails.io/) - Desktop app framework
- [Go](https://go.dev/) - Backend
- [React](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/) + [MUI](https://mui.com/) - Frontend
- [Spotify](https://spotify.com) Web API - Music data
- [TMDB](https://www.themoviedb.org/) API - Movies and TV shows data
- [RAWG](https://rawg.io/) API - Video games data
- [OpenLibrary](https://openlibrary.org/) API - Books data
- [OpenAI](https://openai.com/) API - AI recommendations
- [Google](https://gemini.google.com/) Gemini API - AI recommendations
