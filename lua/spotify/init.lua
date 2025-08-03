-- spoclient.nvim - Neovim plugin for Spotify control
-- MVP skeleton
local M = {}

-- Placeholder for future: OAuth, API, Snacks integration

function M.setup()
  -- Setup config, keymaps, etc
  vim.api.nvim_create_user_command('SpotifyLogin', function()
    require('spotify.oauth').login()
  end, {})
  vim.api.nvim_create_user_command('SpotifyPlaylists', function()
    require('spotify.playlists').show_playlists()
  end, {})
  vim.api.nvim_create_user_command('SpotifySelectDevice', function()
    require('spotify.playlists').select_device()
  end, {})

  local util = require('spotify.util')
  local playlists = require('spotify.playlists')

  vim.api.nvim_create_user_command('Spotify', function()
    util.toggle_playback()
  end, {})

  vim.api.nvim_create_user_command('SpotifyNext', function()
    util.spotify_request {
      url = 'https://api.spotify.com/v1/me/player/next',
      method = 'POST',
      headers = { ['Content-Type'] = 'application/json' },
      device_id = util.load_device_id(),
    }
  end, {})

  vim.api.nvim_create_user_command('SpotifyPrev', function()
    util.spotify_request {
      url = 'https://api.spotify.com/v1/me/player/previous',
      method = 'POST',
      headers = { ['Content-Type'] = 'application/json' },
      device_id = util.load_device_id(),
    }
  end, {})
  vim.api.nvim_create_user_command('SpotifySearch', function(opts)
    require('spotify.search').search(opts.args)
  end, { nargs = 1 })
end
return M
