# spoclient.nvim

A Neovim plugin for controlling Spotify playback directly from your editor.

## Features

- 🎵 Control Spotify playback (play/pause, next/previous, volume)
- 🔍 Search tracks, albums, and playlists
- 📱 Select and manage playback devices
- 📋 Browse playlists and recently played tracks
- ℹ️ Display current track information
- 🔐 Secure OAuth authentication with automatic token refresh

## Requirements

- Neovim 0.5+
- Spotify Premium account (required for playback control)
- `openssl` command-line tool (for OAuth PKCE)
- Internet connection

## Dependencies

- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) - for UI picker
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - for HTTP requests

## Installation

### With LazyVim

1. Copy the plugin files to your Neovim config:
```bash
# In your Neovim config directory
mkdir -p lua/spotify
# Copy all files from lua/spotify/ to your lua/spotify/ directory
```

2. Add the plugin spec to your LazyVim config:
```lua
-- lua/plugins/spotify.lua
return {
  "spoclient.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/spotify",
  config = function()
    require("spotify").setup({
      clientId = "your_spotify_client_id_here"
    })
  end,
  dependencies = {
    "folke/snacks.nvim",
    "nvim-lua/plenary.nvim",
  },
}
```

### With other plugin managers

Install the dependencies and configure similarly, ensuring the plugin files are in your `lua/spotify/` directory.

## Setup

### 1. Create Spotify App

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app
3. Add `http://127.0.0.1:8888/callback` to Redirect URIs
4. Copy your Client ID

### 2. Configure Plugin

Add your Client ID to the setup function:

```lua
require("spotify").setup({
  clientId = "your_spotify_client_id_here"
})
```

### 3. Login

Run `:Spotify auth` to authenticate with Spotify. This will:
- Open your browser for OAuth login
- Store tokens securely in Neovim's data directory
- Automatically refresh tokens as needed

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:Spotify` | Toggle playback (play/pause) |
| `:Spotify auth` | Login to Spotify |
| `:Spotify play` | Resume playback |
| `:Spotify pause` | Pause playback |
| `:Spotify next` | Skip to next track |
| `:Spotify prev` | Skip to previous track |
| `:Spotify vol up` | Increase volume by 10% |
| `:Spotify vol down` | Decrease volume by 10% |
| `:Spotify vol <0-100>` | Set specific volume level |
| `:Spotify info` | Show current track information |
| `:Spotify search <query>` | Search Spotify catalog |
| `:Spotify playlists` | Browse your playlists |
| `:Spotify devices` | Select playback device |
| `:Spotify history` | View recently played tracks |
| `:Spotify status` | Show authentication status |
| `:Spotify help` | Show command help |

### Examples

```vim
:Spotify search daft punk
:Spotify vol 75
:Spotify info
```

## Configuration

The plugin stores authentication tokens and device selection in Neovim's data directory (`stdpath('data')`). No manual configuration files needed.

## Troubleshooting

### Authentication Issues
- Ensure your Spotify app has the correct redirect URI: `http://127.0.0.1:8888/callback`
- Check that your Client ID is correctly set in the setup function
- Try `:Spotify status` to check token status

### Playback Issues
- Spotify Premium account is required for playback control
- Ensure you have an active Spotify device (open Spotify app on any device)
- Use `:Spotify devices` to select the correct playback device

### No Audio/Device Issues
- Open Spotify on any device to make it available
- Use `:Spotify devices` to select your preferred device
- Some devices may not support all playback controls

## License

MIT
