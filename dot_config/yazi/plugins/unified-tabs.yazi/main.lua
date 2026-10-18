local tabs = ya.sync(function()
  local result = {}
  for i = 1, #cx.tabs do
    result[#result + 1] = { on = { tostring(i) }, desc = cx.tabs[i].name }
  end
  return result
end)
return {
  entry = function()
    local choice = ya.which({ cands = tabs() })
    if choice then ya.emit("tab_switch", { choice - 1 }) end
  end,
}
