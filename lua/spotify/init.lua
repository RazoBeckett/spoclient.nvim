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
    print('  :Spotify history      - Recently played tracks')
    print('  :Spotify status       - Show token status')
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
  -- Setup config, keymaps, etc
  if opts and opts.clientId then
    require('spotify.oauth').set_client_id(opts.clientId)
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