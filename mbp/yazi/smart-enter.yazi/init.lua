--- @sync entry

local function entry(self)
	local h = cx.active.current.hovered
	ya.manager_emit(h and h.cha.is_dir and "enter" or "open", { hovered = true, interactive = true })
end

return { entry = entry }