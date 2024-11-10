local vim = vim
local tbl_contains = vim.tbl_contains

local fn = vim.fn
local api = vim.api

local highlight_group = "VisualMatch"

local M = {}
M.opts = {
  min_length = 1,
  highlight = { link = "MatchParen" },
  match_id = 118
}

local visual_matches = {}

local function lines_to_match_string(lines)
  assert(lines ~= nil, "Missing argument 'lines'")

  local escaped_lines = tbl_map(function(line)
    return fn.escape(line, "\\")
  end, lines)

  local text = fn.join(escaped_lines, "\\n")

  if #text ~= 0 then
    return text
  else
    return nil
  end
end

local function match_in_vselection(pos_tbl, lnum, line_len, start_idx, end_idx)
  return lnum >= pos_tbl[1] and lnum <= pos_tbl[3] and
      start_idx >= (lnum == pos_tbl[1] and pos_tbl[2] or 1) and
      end_idx <= (lnum == pos_tbl[3] and pos_tbl[4] or line_len)
end

local function get_screen_text()
  local s_line = vim.fn.line("w0") - 1
  local text_tbl = vim.api.nvim_buf_get_lines(0, s_line, vim.fn.line("w$"), false)

  local screen_text = {}
  for i, line in ipairs(text_tbl) do
    table.insert(screen_text, { s_line + i, line })
  end

  return screen_text
end


local function add_query_matches(hl_group, pos, query_text)
  local query_len = #vim.fn.join(query_text, " ")
  query_text = lines_to_match_string(query_text)

  if not query_text or query_len < M.opts.min_length then
    return nil
  end

  local wins = vim.api.nvim_tabpage_list_wins(0)

  local start_idx = nil
  local end_idx = nil
  local match_positions = {}
  local match_ids = {}

  local subject_text = get_screen_text()
  for _, line_info in ipairs(subject_text) do
    local lnum = line_info[1]
    local line = line_info[2]

    start_idx = 1
    while true do
      start_idx, end_idx = line:find(query_text, start_idx)

      if not start_idx then break end

      if not match_in_vselection(pos, lnum, #line, start_idx, end_idx) then
        table.insert(match_positions, { lnum, start_idx, query_len })
      end

      start_idx = end_idx + 1
    end
  end

  for _, win_id in ipairs(wins) do
    local match_id = vim.fn.matchaddpos(hl_group, match_positions, 100, -1, { window = win_id })
    table.insert(match_ids, { match_id, win_id })
  end

  return match_ids
end


local function remove_visual_selection()
  for _, match in ipairs(visual_matches) do
    local match_id, win_id = match[1], match[2]
    if match_id ~= -1 then
      pcall(fn.matchdelete, match_id, win_id)
    end
  end
  visual_matches = {}
end

local function get_visual_pos(mode)
  local pos_list = fn.getregionpos(fn.getpos('v'), fn.getpos('.'), { type = mode, eol = false })

  local start_pos, end_pos = pos_list[1][1], pos_list[#pos_list][2]
  local start_row, start_col = start_pos[2], start_pos[3]
  local end_row, end_col = end_pos[2], end_pos[3]

  return { start_row, start_col, end_row, end_col }
end

local function get_query_text(pos)
  return api.nvim_buf_get_text(0, pos[1] - 1, pos[2] - 1, pos[3] - 1, pos[4], {})
end

local function match_visual()
  remove_visual_selection()

  local cur_mode = fn.mode()
  if tbl_contains({ "v", "V" }, cur_mode) then
    local pos_tbl = get_visual_pos(cur_mode)
    local visual_text = get_query_text(pos_tbl)
    local matches = add_query_matches(highlight_group, pos_tbl, visual_text)

    visual_matches = matches or {}
  end
end

local function setup(user_cfg)
  M.opts = vim.tbl_extend("force", M.opts, user_cfg or {})

  api.nvim_set_hl(0, highlight_group, M.opts["highlight"])
end

return {
  setup = setup,
  match_visual = match_visual,
  remove_visual_selection = remove_visual_selection
}
