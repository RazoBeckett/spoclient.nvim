-- spotify/oauth.lua
-- Implements PKCE OAuth login for Spotify
local M = {}
local uv = vim.loop
local plenary_curl = require('plenary.curl')

-- URL encode function for query parameters
local function urlencode(str)
  if str == nil then return "" end
  str = tostring(str)
  str = str:gsub("[^%w%-_%.~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return str
end

local client_id = nil
M.client_id = nil
function M.set_client_id(id)
  client_id = id
  M.client_id = id
end
local redirect_uri = "http://127.0.0.1:8888/callback"
-- Make sure these scopes are enabled in your Spotify Developer Dashboard!
local scopes = table.concat({
  "user-read-private",
  "user-read-email",
  "playlist-read-private",
  "user-modify-playback-state",
  "user-read-playback-state",
  "user-library-read",
  "user-read-recently-played",
}, " ")

-- Generate random string for code verifier
local function random_string(len)
  local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  local s = ""
  for i = 1, len do
    local r = math.random(1, #charset)
    s = s .. charset:sub(r, r)
  end
  return s
end

-- SHA256 and base64-url encode (requires openssl)
local function sha256_base64_url(str)
  local handle = io.popen('echo -n "' .. str .. '" | openssl dgst -sha256 -binary | openssl base64')
  local result = handle:read("*a")
  handle:close()
  result = result:gsub("=",""):gsub("%+","-"):gsub("/","_"):gsub("\n","")
  return result
end

function M.login()
  if not client_id then
    print("[Spotify] Client ID not set. Please call require('spotify').setup({ clientId = 'YOUR_CLIENT_ID' })")
    return
  end
  local code_verifier = random_string(64)
  local code_challenge = sha256_base64_url(code_verifier)
  local auth_url = "https://accounts.spotify.com/authorize?" ..
    table.concat({
      "client_id=" .. urlencode(client_id),
      "response_type=code",
      "redirect_uri=" .. urlencode(redirect_uri),
      "scope=" .. urlencode(scopes),
      "code_challenge_method=S256",
      "code_challenge=" .. urlencode(code_challenge),
    }, "&")

  -- Open browser
  vim.fn.jobstart({"xdg-open", auth_url})
  print("Please log in to Spotify in your browser.")

  -- Minimal HTTP server to catch redirect
  local server = uv.new_tcp()
  server:bind("127.0.0.1", 8888)
server:listen(128, function(err)
  assert(not err, err)
  local client = uv.new_tcp()
  server:accept(client)
  client:read_start(function(err, chunk)
    assert(not err, err)
    if chunk then
      local request_line = chunk:match(".-\n")
      local code = nil
      if request_line then
        local code_start = request_line:find("code=")
        if code_start then
          local code_end = request_line:find("&", code_start)
          if code_end then
            code = request_line:sub(code_start + 5, code_end - 1)
          else
            code = request_line:sub(code_start + 5)
          end
        end
      end
      if code then
        -- Remove any trailing HTTP/1.1 or spaces
        code = code:match("^([A-Za-z0-9-_%.~]+)")
        client:write('HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nYou may close this tab.')
        client:shutdown()
        server:close()
        -- Exchange code for token
        M.exchange_token(code, code_verifier)
      end
    end
  end)
end)
end

function M.exchange_token(code, code_verifier)
  if not client_id then
    print("[Spotify] Client ID not configured. Please call require('spotify').setup({ clientId = 'YOUR_CLIENT_ID' })")
    return
  end
  
  local success, result = pcall(plenary_curl.post, "https://accounts.spotify.com/api/token", {
    body = table.concat({
      "client_id=" .. client_id,      
      "grant_type=authorization_code",
    "code=" .. code,
    "redirect_uri=" .. redirect_uri,
    "code_verifier=" .. code_verifier,
  }, "&"),
  headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded"
  },
  callback = function(res)
    if res.status == 200 then
      local json = vim.json.decode(res.body)
      print("[Spotify] Authentication successful!")
      -- Store token securely in local file
      local token_path = vim.fn.stdpath('data') .. '/spotify_token.json'
      local token_data = {
        access_token = json.access_token,
        refresh_token = json.refresh_token,
        expires_in = json.expires_in,
        obtained_at = os.time(),
        token_type = json.token_type or "Bearer",
        scope = json.scope,
      }
      local f = io.open(token_path, 'w')
      if f then
        f:write(vim.json.encode(token_data))
        f:close()
        print('[Spotify] Login complete. You can now use Spotify commands.')
      else
        print('[Spotify] Failed to save authentication data')
      end
    else
      print("[Spotify] Authentication failed: " .. (res.body or "Unknown error"))
    end
  end
})

  if not success then
    print("[Spotify] Network error during authentication. Please check your internet connection.")
  end
end
return M
