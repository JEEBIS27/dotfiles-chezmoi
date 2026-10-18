--- @since 26.8.15
--- @sync entry
-- Yazi has columns, not independent split terminals. Only resize its preview.
return {
  entry = function(state, job)
    local r = rt.mgr.ratio
    local action = job.args[1]
    if action == "zoom" then
      if state.restore then
        rt.mgr.ratio, state.restore = state.restore, nil
      else
        state.restore = { r[1], r[2], r[3] }
        rt.mgr.ratio = { 0, 0, 1 }
      end
    else
      if state.restore then rt.mgr.ratio, state.restore = state.restore, nil; r = rt.mgr.ratio end
      local sum = r[1] + r[2] + r[3]
      local parent = math.floor(r[1] / sum * 100 + 0.5)
      local preview = math.max(10, math.min(80 - parent, math.floor(r[3] / sum * 100 + 0.5) + (action == "grow" and 5 or -5)))
      rt.mgr.ratio = { parent, 100 - parent - preview, preview }
    end
    ya.emit("app:resize", {})
  end,
}
