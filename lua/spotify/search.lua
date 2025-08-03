-- spotify/search.lua
-- Implements global Spotify search and picker
local M = {}
local util = require('spotify.util')
local snacks = require('snacks')

local function urlencode(str)
  if str == nil then return "" end
  str = tostring(str)
  str = str:gsub("[^%w%-_%.~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return str
end

function M.search(term)
  if not term or term == '' then
    print('Usage: :SpotifySearch <search-term>')
    return
  end
  local res = util.spotify_request {
    url = 'https://api.spotify.com/v1/search?q=' .. urlencode(term) .. '&type=track,artist,album,playlist&limit=10',
    method = 'GET',
  }
  if not res or res.status ~= 200 then
    print('Failed to search: ' .. (res and res.body or 'No response'))
    return
  end
  local json = vim.fn.json_decode(res.body)
  local items = {}
  -- Add tracks
  for _, track in ipairs(json.tracks and json.tracks.items or {}) do
    table.insert(items, {
      label = track.name,
      value = { type = 'track', id = track.id },
      description = 'Track · ' .. (track.artists[1] and track.artists[1].name or '') .. ' · ' .. (track.album and track.album.name or ''),
      text = track.name .. ' ' .. (track.artists[1] and track.artists[1].name or '') .. ' ' .. (track.album and track.album.name or ''),
    })
  end
  -- Add albums
  for _, album in ipairs(json.albums and json.albums.items or {}) do
    table.insert(items, {
      label = album.name,
      value = { type = 'album', id = album.id },
      description = 'Album · ' .. (album.artists[1] and album.artists[1].name or ''),
      text = album.name .. ' ' .. (album.artists[1] and album.artists[1].name or ''),
    })
  end
  -- Add artists
  for _, artist in ipairs(json.artists and json.artists.items or {}) do
    table.insert(items, {
      label = artist.name,
      value = { type = 'artist', id = artist.id },
      description = 'Artist',
      text = artist.name,
    })
  end
  -- Add playlists
  local playlists = json.playlists and json.playlists.items or {}
  if type(playlists) == 'userdata' then
    playlists = vim.tbl_values(playlists)
  end
  for _, playlist in ipairs(playlists) do
    if type(playlist) == 'table' then
      table.insert(items, {
        label = playlist.name,
        value = { type = 'playlist', id = playlist.id },
        description = 'Playlist · ' .. (playlist.owner and playlist.owner.display_name or ''),
        text = playlist.name .. ' ' .. (playlist.owner and playlist.owner.display_name or ''),
      })
    end
  end
  if #items == 0 then
    print('No results found.')
    return
  end
  snacks.picker({
    items = items,
    prompt = 'Spotify Search Results',
    format = function(item, _)
      return {
        { item.label, 'Title' },
        { item.description, 'Comment' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      local v = item.value
      if v.type == 'track' then
        -- Play track
        local play_body = vim.fn.json_encode({ uris = { 'spotify:track:' .. v.id } })
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
      elseif v.type == 'album' then
        -- Show album tracks
        local album_res = util.spotify_request {
          url = 'https://api.spotify.com/v1/albums/' .. v.id .. '/tracks',
          method = 'GET',
        }
        if album_res and album_res.status == 200 then
          local album_json = vim.fn.json_decode(album_res.body)
          local track_items = {}
          for _, track in ipairs(album_json.items or {}) do
            table.insert(track_items, {
              label = track.name,
              value = track.id,
              description = 'Track · ' .. (track.artists[1] and track.artists[1].name or ''),
              text = track.name .. ' ' .. (track.artists[1] and track.artists[1].name or ''),
            })
          end
          snacks.picker({
            items = track_items,
            prompt = 'Album Tracks',
            format = function(item, _)
              return {
                { item.label, 'Title' },
                { item.description, 'Comment' },
              }
            end,
            confirm = function(picker2, track_item)
              picker2:close()
              local play_body = vim.fn.json_encode({ uris = { 'spotify:track:' .. track_item.value } })
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
          print('Failed to fetch album tracks: ' .. (album_res and album_res.body or 'No response'))
        end
      elseif v.type == 'playlist' then
        -- Show playlist tracks
        local pl_res = util.spotify_request {
          url = 'https://api.spotify.com/v1/playlists/' .. v.id .. '/tracks',
          method = 'GET',
        }
        if pl_res and pl_res.status == 200 then
          local pl_json = vim.fn.json_decode(pl_res.body)
          local track_items = {}
          for _, track_obj in ipairs(pl_json.items or {}) do
            local track = track_obj.track
            table.insert(track_items, {
              label = track.name,
              value = track.id,
              description = 'Track · ' .. (track.artists[1] and track.artists[1].name or ''),
              text = track.name .. ' ' .. (track.artists[1] and track.artists[1].name or ''),
            })
          end
          snacks.picker({
            items = track_items,
            prompt = 'Playlist Tracks',
            format = function(item, _)
              return {
                { item.label, 'Title' },
                { item.description, 'Comment' },
              }
            end,
            confirm = function(picker2, track_item)
              picker2:close()
              local play_body = vim.fn.json_encode({ uris = { 'spotify:track:' .. track_item.value } })
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
          print('Failed to fetch playlist tracks: ' .. (pl_res and pl_res.body or 'No response'))
        end
      elseif v.type == 'artist' then
        -- Show artist top tracks
        local art_res = util.spotify_request {
          url = 'https://api.spotify.com/v1/artists/' .. v.id .. '/top-tracks?market=US',
          method = 'GET',
        }
        if art_res and art_res.status == 200 then
          local art_json = vim.fn.json_decode(art_res.body)
          local track_items = {}
          for _, track in ipairs(art_json.tracks or {}) do
            table.insert(track_items, {
              label = track.name,
              value = track.id,
              description = 'Track · ' .. (track.artists[1] and track.artists[1].name or ''),
              text = track.name .. ' ' .. (track.artists[1] and track.artists[1].name or ''),
            })
          end
          snacks.picker({
            items = track_items,
            prompt = 'Artist Top Tracks',
            format = function(item, _)
              return {
                { item.label, 'Title' },
                { item.description, 'Comment' },
              }
            end,
            confirm = function(picker2, track_item)
              picker2:close()
              local play_body = vim.fn.json_encode({ uris = { 'spotify:track:' .. track_item.value } })
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
          print('Failed to fetch artist top tracks: ' .. (art_res and art_res.body or 'No response'))
        end
      end
    end,
  })
end

return M
