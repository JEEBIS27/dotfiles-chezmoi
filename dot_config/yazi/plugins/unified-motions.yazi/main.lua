--- @since 26.8.15
-- Read a Vim-style count without changing ordinary motions or operators.
local keys = {}
for digit = 0, 9 do keys[#keys + 1] = { on = tostring(digit) } end
for _, key in ipairs({ "j", "k", "<Down>", "<Up>", "G", "g" }) do
  keys[#keys + 1] = { on = key }
end

local jump = ya.sync(function(_, count)
  ya.emit("arrow", { count - 1 - cx.active.current.cursor })
end)

return {
  entry = function(_, job)
    local count = tonumber(job.args[1])
    if not count or count < 1 then return end
    while true do
      local choice = ya.which({ cands = keys, silent = true })
      if not choice then return end -- Esc cancels; the count is local to this invocation.
      local key = keys[choice].on
      local digit = tonumber(key)
      if digit then
        count = math.min(count * 10 + digit, 999999999)
      elseif key == "j" or key == "<Down>" then
        ya.emit("arrow", { count })
        return
      elseif key == "k" or key == "<Up>" then
        ya.emit("arrow", { -count })
        return
      elseif key == "G" then
        jump(count)
        return
      elseif key == "g" then
        if ya.which({ cands = { { on = "g" } }, silent = true }) then jump(count) end
        return
      end
    end
  end,
}
