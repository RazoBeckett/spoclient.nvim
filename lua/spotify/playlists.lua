-- spotify/playlists.lua
-- Fetches user playlists and shows in Snacks.picker
local M = {}
local util = require('spotify.util')
local snacks = require('snacks')


function M.show_playlists()
  local res = util.spotify_request {
    url = 'https://api.spotify.com/v1/me/playlists',
    method = 'GET',
  }
  if not res then return end
  if res.status == 200 then
    local json = vim.fn.json_decode(res.body)
    local items = {}
    for _, playlist in ipairs(json.items or {}) do
      table.insert(items, {
        label = playlist.name,
        value = playlist.id,
        description = playlist.owner.display_name or '',
        text = playlist.name,
      })
    end
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
        vim.schedule(function()
          local tracks_res = util.spotify_request {
            url = 'https://api.spotify.com/v1/playlists/' .. item.value .. '/tracks',
            method = 'GET',
          }
          if tracks_res and tracks_res.status == 200 then
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
            snacks.picker({
              items = track_items,
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
                local track_index = nil
                for i, t in ipairs(track_items) do
                  if t.value == track_item.value then
                    track_index = i - 1
                    break
                  end
                end
                local play_body = vim.fn.json_encode({
                  context_uri = 'spotify:playlist:' .. item.value,
                  offset = { position = track_index }
                })
                local play_res = util.spotify_request {
                  url = 'https://api.spotify.com/v1/me/player/play',
                  method = 'PUT',
                  headers = { ['Content-Type'] = 'application/json' },
                  body = play_body,
                  device_id = util.load_device_id(),
                }
                if play_res and play_res.status == 204 then
                  print('Playback started.')
                else
                  print('Failed to start playback: ' .. (play_res and play_res.body or 'No response'))
                end
              end,
            })
          else
            print('Failed to fetch tracks: ' .. (tracks_res and tracks_res.body or 'No response'))
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
  local res = util.spotify_request {
    url = 'https://api.spotify.com/v1/me/player/devices',
    method = 'GET',
  }
  if not res then return end
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
        if util.save_device_id(item.value) then
          print('Device ID saved for playback.')
          -- Transfer playback to the selected device and start playing
          local transfer_body = vim.fn.json_encode({
            device_ids = { item.value },
            play = true
          })
          local transfer_res = util.spotify_request {
            url = 'https://api.spotify.com/v1/me/player',
            method = 'PUT',
            headers = { ['Content-Type'] = 'application/json' },
            body = transfer_body,
          }
          if transfer_res and transfer_res.status == 204 then
            print('Playback transferred to device: ' .. item.label)
          else
            print('Failed to transfer playback: ' .. (transfer_res and transfer_res.body or 'No response'))
          end
        else
          print('Failed to save device ID.')
        end
      end,
    })
  else
    print('Failed to fetch devices: ' .. res.body)
  end
end


return M
