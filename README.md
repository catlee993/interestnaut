# Interestnaut

A desktop application for managing your Spotify library and getting AI-powered recommendations. Built with Wails, Go, and React.

## Features

- View your saved media
- Search and add new media to your library
- Remove media from your library
- Preview track audio
- Add media to watch/read lists
- AI-powered media recommendations (music, movies, shows, vide games, and books)
- Multi-LLM support (OpenAI and Google Gemini)

## LLM Providers

Interestnaut supports multiple LLM providers for AI-powered recommendations:

- **OpenAI** (default): Uses the OpenAI GPT models for generating recommendations
- **Google Gemini**: Uses Google's Gemini models as an alternative

You can switch between providers in the Settings panel. The application dynamically uses the selected provider without requiring a restart.

### Setting Up LLM Providers

1. Click on the Settings icon in the app
2. Navigate to the Authentication tab
3. Enter your API key for the provider you want to use
4. Switch to the provider in the Settings tab

## Development

1. Clone the repository
2. Run `wails dev` to start the development server

## Building

Run `wails build` to create a production build.

## Tech Stack

- [Wails](https://wails.io/) - Desktop app framework
- Go - Backend
- React + TypeScript - Frontend
- Spotify Web API - Music data
- OpenAI API - AI recommendations
- Google Gemini API - AI recommendations
