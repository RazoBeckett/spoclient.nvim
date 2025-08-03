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

-- Command handlers
local commands = {
  auth = function()
    require('spotify.oauth').login()
  end,
  
  playlists = function()
    require('spotify.playlists').show_playlists()
  end,
  
  devices = function()
    require('spotify.playlists').select_device()
  end,
  
  play = function()
    local util = require('spotify.util')
    util.spotify_request {
      url = 'https://api.spotify.com/v1/me/player/play',
      method = 'PUT',
      headers = { ['Content-Type'] = 'application/json' },
      device_id = util.load_device_id(),
    }
  end,
  
  pause = function()
    local util = require('spotify.util')
    util.spotify_request {
      url = 'https://api.spotify.com/v1/me/player/pause',
      method = 'PUT',
      headers = { ['Content-Type'] = 'application/json' },
      device_id = util.load_device_id(),
    }
  end,
  
  next = function()
    local util = require('spotify.util')
    util.spotify_request {
      url = 'https://api.spotify.com/v1/me/player/next',
      method = 'POST',
      headers = { ['Content-Type'] = 'application/json' },
      device_id = util.load_device_id(),
    }
  end,
  
  prev = function()
    local util = require('spotify.util')
    util.spotify_request {
      url = 'https://api.spotify.com/v1/me/player/previous',
      method = 'POST',
      headers = { ['Content-Type'] = 'application/json' },
      device_id = util.load_device_id(),
    }
  end,
  
  search = function(query)
    if not query or query == "" then
      print('[Spotify] Usage: :Spotify search <query>')
      return
    end
    require('spotify.search').search(query)
  end,
  
  vol = function(arg)
    local util = require('spotify.util')
    local device_id = util.load_device_id()
    
    if not arg or arg == "" then
      print('[Spotify] Usage: :Spotify vol <up|down|0-100>')
      return
    end
    
    local volume_percent
    if arg == "up" then
      -- Get current volume and increase by 10
      local response = util.spotify_request {
        url = 'https://api.spotify.com/v1/me/player',
        method = 'GET',
      }
      if response and response.status == 200 then
        local data = vim.fn.json_decode(response.body)
        if data and data.device and data.device.volume_percent then
          volume_percent = math.min(100, data.device.volume_percent + 10)
        else
          volume_percent = 50 -- Default if we can't get current volume
        end
      else
        volume_percent = 50
      end
    elseif arg == "down" then
      -- Get current volume and decrease by 10
      local response = util.spotify_request {
        url = 'https://api.spotify.com/v1/me/player',
        method = 'GET',
      }
      if response and response.status == 200 then
        local data = vim.fn.json_decode(response.body)
        if data and data.device and data.device.volume_percent then
          volume_percent = math.max(0, data.device.volume_percent - 10)
        else
          volume_percent = 50
        end
      else
        volume_percent = 50
      end
    else
      -- Parse as number
      volume_percent = tonumber(arg)
      if not volume_percent or volume_percent < 0 or volume_percent > 100 then
        print('[Spotify] Volume must be between 0 and 100')
        return
      end
    end
    
    local url = 'https://api.spotify.com/v1/me/player/volume?volume_percent=' .. volume_percent
    if device_id then
      url = url .. '&device_id=' .. device_id
    end
    
    local response = util.spotify_request {
      url = url,
      method = 'PUT',
    }
    
    if response and response.status == 204 then
      print('[Spotify] Volume set to ' .. volume_percent .. '%')
    else
      print('[Spotify] Failed to set volume')
    end
  end,
  
  history = function()
    require('spotify.history').show_history()
  end,
  
  status = function()
    local util = require('spotify.util')
    local status = util.get_token_status()
    print('[Spotify] Token Status: ' .. status.status .. ' - ' .. status.message)
    
    local token_data = util.load_token()
    if token_data then
      local expires_at = token_data.obtained_at + token_data.expires_in
      local time_left = expires_at - os.time()
      print('[Spotify] Time until expiry: ' .. math.max(0, time_left) .. ' seconds')
    end
  end,
  
  info = function()
    local util = require('spotify.util')
    local response = util.spotify_request {
      url = 'https://api.spotify.com/v1/me/player',
      method = 'GET',
    }
    
    if not response or response.status ~= 200 then
      print('[Spotify] No active playback')
      return
    end
    
    local data = vim.fn.json_decode(response.body)
    if not data or not data.item then
      print('[Spotify] No active playback')
      return
    end
    
    local track = data.item
    local artists = {}
    for _, artist in ipairs(track.artists) do
      table.insert(artists, artist.name)
    end
    
    local duration_ms = track.duration_ms
    local progress_ms = data.progress_ms or 0
    local duration_min = math.floor(duration_ms / 60000)
    local duration_sec = math.floor((duration_ms % 60000) / 1000)
    local progress_min = math.floor(progress_ms / 60000)
    local progress_sec = math.floor((progress_ms % 60000) / 1000)
    
    print('[Spotify] Now Playing:')
    print('  Track: ' .. track.name)
    print('  Artist(s): ' .. table.concat(artists, ', '))
    print('  Album: ' .. track.album.name)
    print('  Progress: ' .. string.format('%d:%02d / %d:%02d', progress_min, progress_sec, duration_min, duration_sec))
    print('  Status: ' .. (data.is_playing and 'Playing' or 'Paused'))
    
    if data.device then
      print('  Device: ' .. data.device.name .. ' (' .. data.device.type .. ')')
      print('  Volume: ' .. (data.device.volume_percent or 'Unknown') .. '%')
    end
  end,
  
  help = function()
    print('[Spotify] Available commands:')
    print('  :Spotify              - Toggle playback (play/pause)')
    print('  :Spotify auth         - Login to Spotify')
    print('  :Spotify playlists    - Show playlists')
    print('  :Spotify devices      - Select device')
    print('  :Spotify play         - Toggle playback')
    print('  :Spotify pause        - Pause playback')
    print('  :Spotify next         - Next track')
    print('  :Spotify prev         - Previous track')
    print('  :Spotify search <query> - Search Spotify')
    print('  :Spotify vol <up|down|0-100> - Control volume')
    print('  :Spotify history      - Recently played tracks')
    print('  :Spotify status       - Show token status')
    print('  :Spotify info         - Show current playing track')
    print('  :Spotify help         - Show this help')
  end,
}

-- Command dispatcher
local function spotify_command(opts)
  local args = vim.split(opts.args, '%s+')
  local subcommand = args[1]
  local rest_args = table.concat(vim.list_slice(args, 2), ' ')
  
  -- Default behavior: if no subcommand, toggle playback
  if not subcommand or subcommand == "" then
    require('spotify.util').toggle_playback()
    return
  end
  
  local handler = commands[subcommand]
  if handler then
    if subcommand == 'search' then
      handler(rest_args)
    elseif subcommand == 'vol' then
      handler(rest_args)
    else
      handler()
    end
  else
    print('[Spotify] Unknown command: ' .. subcommand)
    print('[Spotify] Use ":Spotify help" to see available commands')
  end
end

-- Tab completion for subcommands
local function spotify_complete(arg_lead, cmd_line, cursor_pos)
  local cmd_parts = vim.split(cmd_line, '%s+')
  
  -- If we're completing the first argument (subcommand)
  if #cmd_parts <= 2 then
    local subcommands = vim.tbl_keys(commands)
    return vim.tbl_filter(function(cmd)
      return cmd:find('^' .. arg_lead)
    end, subcommands)
  end
  
  return {}
end

function M.setup(opts)
  -- Validate setup options
  opts = opts or {}
  
  -- Setup config, keymaps, etc
  if opts.clientId then
    if type(opts.clientId) ~= "string" or opts.clientId == "" then
      print("[Spotify] Error: clientId must be a non-empty string")
      return
    end
    require('spotify.oauth').set_client_id(opts.clientId)
  else
    print("[Spotify] Warning: No clientId provided. You'll need to configure it to use the plugin.")
    print("[Spotify] Call require('spotify').setup({ clientId = 'YOUR_CLIENT_ID' })")
  end
  
  -- Check dependencies
  local ok, _ = pcall(require, 'plenary.curl')
  if not ok then
    print("[Spotify] Error: plenary.nvim is required but not found")
    return
  end
  
  local ok, _ = pcall(require, 'snacks')
  if not ok then
    print("[Spotify] Error: snacks.nvim is required but not found")
    return
  end
  
  -- Start background token refresh
  start_token_refresh_timer()
  
  -- Create the main Spotify command with subcommand support
  vim.api.nvim_create_user_command('Spotify', spotify_command, {
    nargs = '*',
    complete = spotify_complete,
    desc = 'Spotify commands - use :Spotify help for usage'
  })
  
  -- Clean up on plugin unload
  vim.api.nvim_create_autocmd('VimLeave', {
    callback = stop_token_refresh_timer,
  })
end
return M