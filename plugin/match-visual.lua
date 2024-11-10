local vim_api = vim.api
local schedule = vim.schedule
local match_vis = require("match-visual")

local aucmd = vim_api.nvim_create_autocmd
local augrp = vim_api.nvim_create_augroup

local group = augrp("MatchVisual", { clear = true })

aucmd("CursorMoved", {
  group = group,
  callback = function()
    schedule(match_vis.match_visual)
  end,
})

aucmd("ModeChanged", {
  group = group,
  pattern = "*:[vV]",
  callback = match_vis.match_visual,
})

aucmd("ModeChanged", {
  group = group,
  pattern = "[vV]:*",
  callback = match_vis.remove_visual_selection,
})
