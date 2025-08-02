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

  local plenary_curl = require('plenary.curl')
  local playlists = require('spotify.playlists')

  vim.api.nvim_create_user_command('SpotifyPlay', function()
    local token_data = playlists.load_token()
    plenary_curl.request({
      url = 'https://api.spotify.com/v1/me/player/play',
      method = 'PUT',
      headers = {
        ['Authorization'] = 'Bearer ' .. token_data.access_token,
        ['Content-Type'] = 'application/json',
      },
    })
  end, {})

  vim.api.nvim_create_user_command('SpotifyPause', function()
    local token_data = playlists.load_token()
    plenary_curl.request({
      url = 'https://api.spotify.com/v1/me/player/pause',
      method = 'PUT',
      headers = {
        ['Authorization'] = 'Bearer ' .. token_data.access_token,
        ['Content-Type'] = 'application/json',
      },
    })
  end, {})

  vim.api.nvim_create_user_command('SpotifyNext', function()
    local token_data = playlists.load_token()
    plenary_curl.request({
      url = 'https://api.spotify.com/v1/me/player/next',
      method = 'POST',
      headers = {
        ['Authorization'] = 'Bearer ' .. token_data.access_token,
        ['Content-Type'] = 'application/json',
      },
    })
  end, {})

  vim.api.nvim_create_user_command('SpotifyPrev', function()
    local token_data = playlists.load_token()
    plenary_curl.request({
      url = 'https://api.spotify.com/v1/me/player/previous',
      method = 'POST',
      headers = {
        ['Authorization'] = 'Bearer ' .. token_data.access_token,
        ['Content-Type'] = 'application/json',
      },
    })
  end, {})
end

return M
