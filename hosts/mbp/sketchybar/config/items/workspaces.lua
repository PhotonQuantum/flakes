local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local query_workspaces =
  "aerospace list-workspaces --all --format '%{workspace}%{workspace-is-focused}%{workspace-is-visible}%{monitor-appkit-nsscreen-screens-id}' --json"
local query_windows =
  "aerospace list-windows --all --format '%{workspace}%{app-name}' --json"

local root = sbar.add("item", {
  icon = { drawing = false },
  label = { drawing = false },
  background = {
    color = colors.bg0,
    height = 28,
    corner_radius = 9,
    drawing = false,
  },
  padding_left = 6,
  padding_right = 0,
})

local workspaces = {}
local refresh_running = false
local refresh_queued = false
local refresh_seq = 0
local active_refresh_seq = 0
local snapshot = {
  focused_workspace = nil,
  visible_by_workspace = {},
  display_by_workspace = {},
  apps_by_workspace = {},
}

local function trim(value)
  if value == nil then
    return ""
  end
  return tostring(value):match("^%s*(.-)%s*$")
end

local function icon_line_for_apps(apps)
  if #apps == 0 then
    return " —"
  end

  local icons = {}
  for _, app in ipairs(apps) do
    icons[#icons + 1] = app_icons[app] or app_icons["Default"]
  end

  return " " .. table.concat(icons, " ")
end

local function render_workspace(workspace_index)
  local workspace = workspaces[workspace_index]
  if workspace == nil then
    return
  end

  local apps = snapshot.apps_by_workspace[workspace_index] or {}
  local display_id = snapshot.display_by_workspace[workspace_index]
  local is_visible = snapshot.visible_by_workspace[workspace_index] ~= nil
  local is_focused = snapshot.focused_workspace == workspace_index
  local has_apps = #apps > 0
  local show_placeholder = not has_apps and (is_visible or is_focused)
  local show_content = has_apps or show_placeholder

  workspace:set({
    display = display_id,
    icon = {
      drawing = show_content,
      highlight = is_focused,
    },
    label = {
      drawing = show_content,
      highlight = is_focused,
      string = icon_line_for_apps(apps),
      font = "sketchybar-app-font:Regular:16.0",
      y_offset = -1,
    },
    background = {
      drawing = is_visible,
    },
    padding_left = show_content and 1 or 0,
    padding_right = show_content and 1 or 0,
  })
end

local function render_all_workspaces()
  for workspace_index, _ in pairs(workspaces) do
    render_workspace(workspace_index)
  end
end

local function set_visible_workspace_for_display(display_id, workspace_index)
  local changed_workspaces = {}

  if display_id == nil then
    return changed_workspaces
  end

  for candidate_workspace, candidate_display_id in pairs(snapshot.visible_by_workspace) do
    if candidate_display_id == display_id and candidate_workspace ~= workspace_index then
      snapshot.visible_by_workspace[candidate_workspace] = nil
      changed_workspaces[#changed_workspaces + 1] = candidate_workspace
    end
  end

  if workspace_index ~= nil then
    snapshot.visible_by_workspace[workspace_index] = display_id
    changed_workspaces[#changed_workspaces + 1] = workspace_index
  end

  return changed_workspaces
end

local function build_snapshot(callback)
  sbar.exec(query_workspaces, function(workspace_entries)
    sbar.exec(query_windows, function(workspace_windows)
      local next_snapshot = {
        focused_workspace = "",
        visible_by_workspace = {},
        display_by_workspace = {},
        apps_by_workspace = {},
      }

      for _, entry in ipairs(workspace_entries) do
        local workspace_index = entry.workspace
        local display_id = math.floor(entry["monitor-appkit-nsscreen-screens-id"])

        next_snapshot.display_by_workspace[workspace_index] = display_id
        if entry["workspace-is-visible"] then
          next_snapshot.visible_by_workspace[workspace_index] = display_id
        end
        if entry["workspace-is-focused"] then
          next_snapshot.focused_workspace = workspace_index
        end
      end

      for _, entry in ipairs(workspace_windows) do
        local workspace_index = entry.workspace
        local apps = next_snapshot.apps_by_workspace[workspace_index]
        if apps == nil then
          apps = {}
          next_snapshot.apps_by_workspace[workspace_index] = apps
        end
        apps[#apps + 1] = entry["app-name"]
      end

      callback(next_snapshot)
    end)
  end)
end

local function render_workspaces(workspace_indices)
  local seen = {}
  for _, workspace_index in ipairs(workspace_indices) do
    if workspace_index ~= "" and not seen[workspace_index] then
      seen[workspace_index] = true
      render_workspace(workspace_index)
    end
  end
end

local function refresh_workspaces()
  refresh_seq = refresh_seq + 1

  if refresh_running then
    refresh_queued = true
    return
  end

  refresh_running = true
  active_refresh_seq = refresh_seq
  build_snapshot(function(next_snapshot)
    local is_latest_refresh = active_refresh_seq == refresh_seq

    if is_latest_refresh then
      snapshot = next_snapshot
      render_all_workspaces()
    end

    refresh_running = false
    active_refresh_seq = 0
    if refresh_queued or not is_latest_refresh then
      refresh_queued = false
      refresh_workspaces()
    end
  end)
end

local function fast_switch_workspace(env)
  local next_workspace = trim(env.FOCUSED_WORKSPACE)
  local prev_workspace = trim(env.PREV_WORKSPACE or snapshot.focused_workspace)

  if next_workspace == "" then
    refresh_workspaces()
    return
  end

  local next_display_id = snapshot.display_by_workspace[next_workspace]
  local changed_workspaces = { prev_workspace, next_workspace }
  if next_display_id ~= nil then
    local visibility_changes = set_visible_workspace_for_display(next_display_id, next_workspace)
    for _, workspace_index in ipairs(visibility_changes) do
      changed_workspaces[#changed_workspaces + 1] = workspace_index
    end
  end

  snapshot.focused_workspace = next_workspace
  render_workspaces(changed_workspaces)
end

sbar.exec(query_workspaces, function(workspace_entries)
  for _, entry in ipairs(workspace_entries) do
    local workspace_index = entry.workspace

    workspaces[workspace_index] = sbar.add("item", {
      icon = {
        color = colors.with_alpha(colors.white, 0.6),
        highlight_color = colors.white,
        drawing = false,
        font = { family = settings.font.numbers },
        string = workspace_index,
        padding_left = 10,
        padding_right = 5,
      },
      label = {
        padding_right = 10,
        color = colors.with_alpha(colors.white, 0.6),
        highlight_color = colors.white,
        font = "sketchybar-app-font:Regular:16.0",
        y_offset = -1,
        drawing = false,
      },
      padding_right = 0,
      padding_left = 0,
      background = {
        color = colors.bg3,
        height = 28,
        drawing = false,
      },
      click_script = "aerospace workspace " .. workspace_index,
      blur_radius = 30,
    })
  end

  refresh_workspaces()

  root:subscribe("aerospace_workspace_change", fast_switch_workspace)
  root:subscribe("aerospace_focus_change", refresh_workspaces)
  root:subscribe("display_change", refresh_workspaces)
end)
