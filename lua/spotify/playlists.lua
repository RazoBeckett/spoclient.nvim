-- spotify/playlists.lua
-- Fetches user playlists and shows in Snacks.picker
local M = {}
local plenary_curl = require('plenary.curl')
local snacks = require('snacks')

function M.load_token()
  local token_path = vim.fn.stdpath('data') .. '/spotify_token.json'
  local f = io.open(token_path, 'r')
  if not f then return nil end
  local data = f:read('*a')
  f:close()
  return vim.fn.json_decode(data)
end

local function load_token()
  local token_path = vim.fn.stdpath('data') .. '/spotify_token.json'
  local f = io.open(token_path, 'r')
  if not f then return nil end
  local data = f:read('*a')
  f:close()
  return vim.fn.json_decode(data)
end

function M.show_playlists()
  local token_data = load_token()
  if not token_data or not token_data.access_token then
    print('Spotify access token not found. Please login.')
    return
  end
  local res = plenary_curl.get('https://api.spotify.com/v1/me/playlists', {
    headers = {
      ['Authorization'] = 'Bearer ' .. token_data.access_token
    }
  })
  if res.status == 200 then
    local json = vim.fn.json_decode(res.body)
    local items = {}
    for _, playlist in ipairs(json.items or {}) do
table.insert(items, {
  label = playlist.name,
  value = playlist.id,
  description = playlist.owner.display_name or '',
  text = playlist.name,
})    end
snacks.picker({
  items = items,
  prompt = 'Select Playlist',
  format = function(item, _)
    return {
      { item.label, "Title" },
      { item.description, "Comment" },
    }
  end,
  confirm = function(picker, item)
    picker:close()
    print('Selected playlist: ' .. item.label)
    -- Close playlist picker and open song picker
    vim.schedule(function()
      -- Load tracks for selected playlist
      local tracks_res = plenary_curl.get('https://api.spotify.com/v1/playlists/' .. item.value .. '/tracks', {
        headers = {
          ['Authorization'] = 'Bearer ' .. token_data.access_token
        }
      })
      if tracks_res.status == 200 then
        local tracks_json = vim.fn.json_decode(tracks_res.body)
        local track_items = {}
        for _, track_obj in ipairs(tracks_json.items or {}) do
          local track = track_obj.track
          table.insert(track_items, {
  label = track.name,
  value = track.id,
  description = (track.artists[1] and track.artists[1].name or '') .. ' - ' .. (track.album and track.album.name or ''),
  text = track.name .. ' ' .. (track.artists[1] and track.artists[1].name or '') .. ' ' .. (track.album and track.album.name or ''),
})
        end
        snacks.picker({  items = track_items,
  prompt = 'Select Song',
  format = function(item, _)
    return {
      { item.label, "Title" },
      { item.description, "Comment" },
    }
  end,
  confirm = function(picker, track_item)
  picker:close()
  print('Playing song: ' .. track_item.label)
  -- Find track index in track_items
  local track_index = nil
  for i, t in ipairs(track_items) do
    if t.value == track_item.value then
      track_index = i - 1 -- Spotify uses zero-based index
      break
    end
  end
  local play_url = 'https://api.spotify.com/v1/me/player/play'
  local device_id = M.load_device_id()
  if device_id then
    play_url = play_url .. '?device_id=' .. device_id
  end
  local play_body = vim.fn.json_encode({
    context_uri = 'spotify:playlist:' .. item.value,
    offset = { position = track_index }
  })
  local res = plenary_curl.request({
    url = play_url,
    method = 'PUT',
    headers = {
      ['Authorization'] = 'Bearer ' .. token_data.access_token,
      ['Content-Type'] = 'application/json',
    },
    body = play_body,
  })
  if res.status == 204 then
    print('Playback started.')
  else
    print('Failed to start playback: ' .. res.body)
  end
end,
})          else
            print('Failed to fetch tracks: ' .. tracks_res.body)
          end
        end)
      end,
    })
  else
    print('Failed to fetch playlists: ' .. res.body)
  end
end

-- Select a device and store its ID
function M.select_device()
  local token_data = load_token()
  if not token_data or not token_data.access_token then
    print('Spotify access token not found. Please login.')
    return
  end
  local res = plenary_curl.get('https://api.spotify.com/v1/me/player/devices', {
    headers = {
      ['Authorization'] = 'Bearer ' .. token_data.access_token
    }
  })
  if res.status == 200 then
    local json = vim.fn.json_decode(res.body)
    local items = {}
    for _, device in ipairs(json.devices or {}) do
      table.insert(items, {
        label = device.name,
        value = device.id,
        description = device.type .. (device.is_active and ' (active)' or ''),
        text = device.name,
      })
    end
    if #items == 0 then
      print('No available Spotify devices found. Open Spotify on a device and try again.')
      return
    end
    snacks.picker({
      items = items,
      prompt = 'Select Spotify Device',
      format = function(item, _)
        return {
          { item.label, "Name" },
          { item.description, "Type" },
        }
      end,
      confirm = function(picker, item)
        picker:close()
        print('Selected device: ' .. item.label)
        local device_path = vim.fn.stdpath('data') .. '/spotify_device.json'
        local f = io.open(device_path, 'w')
        if f then
          f:write(vim.fn.json_encode({ device_id = item.value }))
          f:close()
          print('Device ID saved for playback.')
        else
          print('Failed to save device ID.')
        end
      end,
    })
  else
    print('Failed to fetch devices: ' .. res.body)
  end
end

-- Load selected device ID
function M.load_device_id()
  local device_path = vim.fn.stdpath('data') .. '/spotify_device.json'
  local f = io.open(device_path, 'r')
  if not f then return nil end
  local data = f:read('*a')
  f:close()
  local obj = vim.fn.json_decode(data)
  return obj and obj.device_id or nil
end

return M
