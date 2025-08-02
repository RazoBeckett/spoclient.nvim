-- spotify.nvim - Neovim plugin for Spotify control
-- MVP skeleton
local M = {}

-- Placeholder for future: OAuth, API, Snacks integration

function M.setup()
  -- Setup config, keymaps, etc
  vim.api.nvim_create_user_command('SpotifyLogin', function()
    require('spotify.oauth').login()
  end, {})
  vim.api.nvim_create_user_command('SpotifyPlaylists', function()
    require('spotify.playlists').show_playlists()
  end, {})
end

return M
