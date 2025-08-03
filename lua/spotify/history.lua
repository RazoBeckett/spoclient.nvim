-- spotify/history.lua
-- Show recently played tracks
local M = {}
local util = require('spotify.util')

-- Helper to format time
local function format_time(iso)
  return iso:sub(1, 16):gsub('T', ' ')
end

function M.show_history(opts)
  local res = util.spotify_request {
    url = 'https://api.spotify.com/v1/me/player/recently-played?limit=20',
    method = 'GET',
  }
  if not res or res.status ~= 200 then
    print('[Spotify] Failed to fetch listening history. Please try again.')
    return
  end
  local data = vim.fn.json_decode(res.body)
  if not data or not data.items or #data.items == 0 then
    print('[Spotify] No recent listening history found.')
    return
  end
  local picker_items = {}
  for i, item in ipairs(data.items) do
    local track = item.track
    local artists = {}
    for _, a in ipairs(track.artists) do table.insert(artists, a.name) end
    local label = track.name
    local description = table.concat(artists, ', ') .. ' [' .. format_time(item.played_at) .. ']'
    local text = track.name .. ' ' .. table.concat(artists, ', ')
    table.insert(picker_items, {
      label = label,
      value = track.uri,
      description = description,
      text = text,
    })
  end
  local snacks = require('snacks')
  snacks.picker({
    items = picker_items,
    prompt = 'Select a track to play',
    format = function(item, _)
      return {
        { item.label, "Title" },
        { item.description, "Comment" },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if not item or not item.value then return end
      local device_id = util.load_device_id()
      local play_res = util.spotify_request {
        url = 'https://api.spotify.com/v1/me/player/play' .. (device_id and ('?device_id=' .. device_id) or ''),
        method = 'PUT',
        headers = { ['Content-Type'] = 'application/json' },
        body = vim.fn.json_encode({ uris = { item.value } }),
      }
      if play_res and play_res.status == 204 then
        snacks.notifier.notify('Playing: ' .. item.label)
      else
        snacks.notifier.notify('Failed to play track.', 'error')
      end
    end,
  })
end

return M
