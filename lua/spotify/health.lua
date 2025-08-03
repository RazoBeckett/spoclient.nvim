-- spotify/health.lua
-- Health check for :checkhealth spotify
local M = {}

function M.check()
  vim.health.start("Spotify Plugin")
  
  -- Check dependencies
  local ok, plenary = pcall(require, 'plenary.curl')
  if ok then
    vim.health.ok("plenary.nvim is installed")
  else
    vim.health.error("plenary.nvim is not installed", "Install with your plugin manager")
  end
  
  local ok, snacks = pcall(require, 'snacks')
  if ok then
    vim.health.ok("snacks.nvim is installed")
  else
    vim.health.error("snacks.nvim is not installed", "Install with your plugin manager")
  end
  
  -- Check openssl
  local handle = io.popen("command -v openssl")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result and result ~= "" then
      vim.health.ok("openssl is available")
    else
      vim.health.error("openssl not found", "Install openssl for OAuth authentication")
    end
  else
    vim.health.error("openssl not found", "Install openssl for OAuth authentication")
  end
  
  -- Check configuration
  local oauth = require('spotify.oauth')
  if oauth.client_id and oauth.client_id ~= "" then
    vim.health.ok("Client ID is configured")
  else
    vim.health.warn("Client ID not configured", "Call require('spotify').setup({ clientId = 'YOUR_CLIENT_ID' })")
  end
  
  -- Check token
  local util = require('spotify.util')
  local token_data = util.load_token()
  if token_data and token_data.access_token then
    if util.is_token_expired(token_data) then
      vim.health.warn("Access token is expired", "Run :Spotify auth to re-authenticate")
    else
      vim.health.ok("Access token is valid")
    end
  else
    vim.health.info("Not authenticated", "Run :Spotify auth to login")
  end
  
  -- Check network connectivity
  if ok then
    local success, _ = pcall(plenary.get, 'https://api.spotify.com/', { timeout = 5000 })
    if success then
      vim.health.ok("Can reach Spotify API")
    else
      vim.health.warn("Cannot reach Spotify API", "Check your internet connection")
    end
  end
end

return M