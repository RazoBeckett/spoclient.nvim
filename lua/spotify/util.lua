-- spotify/util.lua
-- Utility functions for token/device loading and Spotify API requests
local M = {}
local plenary_curl = require('plenary.curl')

-- Load Spotify access token from file
function M.load_token()
  local token_path = vim.fn.stdpath('data') .. '/spotify_token.json'
  local f = io.open(token_path, 'r')
  if not f then return nil end
  local data = f:read('*a')
  f:close()
  return vim.fn.json_decode(data)
end

-- Load selected device ID from file
function M.load_device_id()
  local device_path = vim.fn.stdpath('data') .. '/spotify_device.json'
  local f = io.open(device_path, 'r')
  if not f then return nil end
  local data = f:read('*a')
  f:close()
  local obj = vim.fn.json_decode(data)
  return obj and obj.device_id or nil
end

-- Save selected device ID to file
function M.save_device_id(device_id)
  local device_path = vim.fn.stdpath('data') .. '/spotify_device.json'
  local f = io.open(device_path, 'w')
  if f then
    f:write(vim.fn.json_encode({ device_id = device_id }))
    f:close()
    return true
  end
  return false
end

-- Make a Spotify API request (adds token and device if provided)
function M.spotify_request(opts)
  local token_data = M.load_token()
  if not token_data or not token_data.access_token then
    print('Spotify access token not found. Please login.')
    return nil
  end
  opts.headers = opts.headers or {}
  opts.headers['Authorization'] = 'Bearer ' .. token_data.access_token
  if opts.device_id then
    opts.url = opts.url .. '?device_id=' .. opts.device_id
    opts.device_id = nil
  end
  return plenary_curl.request(opts)
end

function M.toggle_playback()
  local device_id = M.load_device_id()
  local state_res = M.spotify_request {
    url = 'https://api.spotify.com/v1/me/player',
    method = 'GET',
    device_id = device_id,
  }
  if not state_res or state_res.status ~= 200 then
    print('Failed to get playback state.')
    return
  end
  local state = vim.fn.json_decode(state_res.body)
  if state and state.is_playing then
    local pause_res = M.spotify_request {
      url = 'https://api.spotify.com/v1/me/player/pause',
      method = 'PUT',
      headers = { ['Content-Type'] = 'application/json' },
      device_id = device_id,
    }
    if pause_res and pause_res.status == 204 then
      print('Playback paused.')
    else
      print('Failed to pause playback.')
    end
  else
    local play_res = M.spotify_request {
      url = 'https://api.spotify.com/v1/me/player/play',
      method = 'PUT',
      headers = { ['Content-Type'] = 'application/json' },
      device_id = device_id,
    }
    if play_res and play_res.status == 204 then
      print('Playback started.')
    else
      print('Failed to start playback.')
    end
  end
end

-- Check if access token is expired
function M.is_token_expired(token_data)
  if not token_data or not token_data.access_token or not token_data.expires_in or not token_data.obtained_at then
    return true
  end
  local now = os.time()
  -- Give a 30s buffer for network delay
  return (token_data.obtained_at + token_data.expires_in - 30) < now
end

-- Refresh access token using refresh token
function M.refresh_access_token(token_data)
  if not token_data or not token_data.refresh_token then
    print('No refresh token available. Please login again.')
    return nil
  end
  local client_id = require('spotify.oauth').client_id or nil
  if not client_id then
    print('Spotify client_id not set. Please call require("spotify").setup({ clientId = "YOUR_CLIENT_ID" })')
    return nil
  end
  local plenary_curl = require('plenary.curl')
  local res = plenary_curl.post('https://accounts.spotify.com/api/token', {
    body = table.concat({
      'client_id=' .. client_id,
      'grant_type=refresh_token',
      'refresh_token=' .. token_data.refresh_token,
    }, '&'),
    headers = {
      ['Content-Type'] = 'application/x-www-form-urlencoded'
    },
  })
  if res.status == 200 then
    local json = vim.fn.json_decode(res.body)
    -- Update token file
    local new_token_data = {
      access_token = json.access_token,
      refresh_token = token_data.refresh_token, -- Spotify may not return a new refresh token
      expires_in = json.expires_in,
      obtained_at = os.time(),
    }
    local token_path = vim.fn.stdpath('data') .. '/spotify_token.json'
    local f = io.open(token_path, 'w')
    if f then
      f:write(vim.fn.json_encode(new_token_data))
      f:close()
    end
    print('Spotify access token refreshed.')
    return new_token_data
  else
    print('Failed to refresh access token:', res.body)
    return nil
  end
end

-- Make a Spotify API request (adds token and device if provided)
function M.spotify_request(opts)
  local token_data = M.load_token()
  if not token_data or not token_data.access_token then
    print('Spotify access token not found. Please login.')
    return nil
  end
  if M.is_token_expired(token_data) then
    print('Spotify access token expired. Refreshing...')
    token_data = M.refresh_access_token(token_data)
    if not token_data or not token_data.access_token then
      print('Failed to refresh token. Please login again.')
      return nil
    end
  end
  opts.headers = opts.headers or {}
  opts.headers['Authorization'] = 'Bearer ' .. token_data.access_token
  if opts.device_id then
    opts.url = opts.url .. '?device_id=' .. opts.device_id
    opts.device_id = nil
  end
  return plenary_curl.request(opts)
end

return M
