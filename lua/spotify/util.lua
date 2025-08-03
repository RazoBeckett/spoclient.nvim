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

return M
