# Interestnaut

A desktop application for managing your Spotify library. Built with Wails, Go, and React.

## Features

- View your saved tracks
- Search and add new tracks to your library
- Remove tracks from your library
- Preview track audio
- Clean, modern interface

## Development

1. Clone the repository
2. Create a `.env` file with your Spotify credentials:
   ```
   SPOTIFY_CLIENT_ID=your_client_id
   SPOTIFY_CLIENT_SECRET=your_client_secret
   ```
3. Run `wails dev` to start the development server

## Building

Run `wails build` to create a production build.

## Tech Stack

- [Wails](https://wails.io/) - Desktop app framework
- Go - Backend
- React + TypeScript - Frontend
- Spotify Web API - Music data
