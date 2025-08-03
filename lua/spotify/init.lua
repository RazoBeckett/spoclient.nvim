-- spoclient.nvim - Neovim plugin for Spotify control
-- MVP skeleton
local M = {}

-- Background token refresh timer
local token_refresh_timer = nil

-- Start background token validation
local function start_token_refresh_timer()
  if token_refresh_timer then
    return -- Already running
  end
  
  token_refresh_timer = vim.loop.new_timer()
  if not token_refresh_timer then
    return
  end
  
  -- Check token every 30 minutes (1800000 ms)
  token_refresh_timer:start(1800000, 1800000, vim.schedule_wrap(function()
    local util = require('spotify.util')
    local token_data = util.load_token()
    
    if token_data and util.token_needs_refresh(token_data) then
      print('[Spotify] Background token refresh...')
      util.refresh_access_token(token_data)
    end
  end))
end

-- Stop background token validation
local function stop_token_refresh_timer()
  if token_refresh_timer then
    token_refresh_timer:stop()
    token_refresh_timer:close()
    token_refresh_timer = nil
  end
end

-- Placeholder for future: OAuth, API, Snacks integration

function M.setup(opts)
  -- Setup config, keymaps, etc
  if opts and opts.clientId then
    require('spotify.oauth').set_client_id(opts.clientId)
  end
  
  -- Start background token refresh
  start_token_refresh_timer()
  
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

  vim.api.nvim_create_user_command('SpotifyHistory', function()
    require('spotify.history').show_history()
  end, {})
  
  -- Debug command to check token status
  vim.api.nvim_create_user_command('SpotifyTokenStatus', function()
    local util = require('spotify.util')
    local status = util.get_token_status()
    print('[Spotify] Token Status: ' .. status.status .. ' - ' .. status.message)
    
    local token_data = util.load_token()
    if token_data then
      local expires_at = token_data.obtained_at + token_data.expires_in
      local time_left = expires_at - os.time()
      print('[Spotify] Time until expiry: ' .. math.max(0, time_left) .. ' seconds')
    end
  end, {})
  
  -- Clean up on plugin unload
  vim.api.nvim_create_autocmd('VimLeave', {
    callback = stop_token_refresh_timer,
  })
end
return M
