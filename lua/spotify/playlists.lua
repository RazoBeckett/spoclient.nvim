-- spotify/playlists.lua
-- Fetches user playlists and shows in Snacks.picker
local M = {}
local plenary_curl = require('plenary.curl')
local snacks = require('snacks')

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
      })
    end
    snacks.picker({
      items = items,
      prompt = 'Select Playlist',
      on_select = function(item)
        print('Selected playlist: ' .. item.label)
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
            })
          end
          snacks.picker({
            items = track_items,
            prompt = 'Select Song',
            on_select = function(track_item)
              print('Selected song: ' .. track_item.label)
              -- Player controls
              local function player_action(action, params)
                local url, method, body = nil, nil, nil
                if action == 'play' then
                  url = 'https://api.spotify.com/v1/me/player/play'
                  method = 'PUT'
                  body = vim.fn.json_encode({ uris = { 'spotify:track:' .. track_item.value } })
                elseif action == 'pause' then
                  url = 'https://api.spotify.com/v1/me/player/pause'
                  method = 'PUT'
                elseif action == 'next' then
                  url = 'https://api.spotify.com/v1/me/player/next'
                  method = 'POST'
                elseif action == 'previous' then
                  url = 'https://api.spotify.com/v1/me/player/previous'
                  method = 'POST'
                elseif action == 'repeat' then
                  url = 'https://api.spotify.com/v1/me/player/repeat?state=track'
                  method = 'PUT'
                end
                if url and method then
                  local res = plenary_curl.request({
                    url = url,
                    method = method,
                    headers = {
                      ['Authorization'] = 'Bearer ' .. token_data.access_token,
                      ['Content-Type'] = 'application/json',
                    },
                    body = body,
                  })
                  if res.status == 204 then
                    print('Spotify action ' .. action .. ' succeeded.')
                  else
                    print('Spotify action ' .. action .. ' failed: ' .. res.body)
                  end
                end
              end
              -- Show Snacks.picker for player controls
              snacks.picker({
                items = {
                  { label = 'Play', value = 'play' },
                  { label = 'Pause', value = 'pause' },
                  { label = 'Next', value = 'next' },
                  { label = 'Previous', value = 'previous' },
                  { label = 'Repeat', value = 'repeat' },
                },
                prompt = 'Player Control',
                on_select = function(ctrl)
                  player_action(ctrl.value)
                end,
              })
            end,
          })
        else
          print('Failed to fetch tracks: ' .. tracks_res.body)
        end
      end,
    })
  else
    print('Failed to fetch playlists: ' .. res.body)
  end
end

return M
