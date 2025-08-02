-- LazyVim plugin spec for spoclient.nvim
return {
  "spoclient.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/spotify",
  config = function()
    require("spotify").setup()
  end,
  dependencies = {
    "folke/snacks.nvim", -- for Snacks.picker
    "nvim-lua/plenary.nvim", -- for HTTP requests
  },
}
