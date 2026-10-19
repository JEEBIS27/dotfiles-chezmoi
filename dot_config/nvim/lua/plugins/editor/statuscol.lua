return {
  {
    "luukvbaal/statuscol.nvim",
    event = "VeryLazy",
    config = function()
      local builtin = require("statuscol.builtin")
      local mode_style = require("utils.mode_colors")
      local function refresh_mode_highlights()
        for scene, color in pairs(mode_style.colors) do
          vim.api.nvim_set_hl(0, "StatusColMode" .. scene, { fg = color })
        end
      end
      refresh_mode_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("StatusColThemeColors", { clear = true }),
        callback = refresh_mode_highlights,
        desc = "statuscolのモード色を現在のThemeに同期",
      })
      local operator_icons = { d = "", y = "", c = "", r = "" }
      _G._my_statuscolumn_operator = nil
      _G._my_statuscolumn_operator_seq = 0

      local function current_mode_icon()
        local mode = vim.api.nvim_get_mode().mode
        if _G._my_statuscolumn_operator then
          return operator_icons[_G._my_statuscolumn_operator] or ""
        elseif mode:sub(1, 1) == "i" then
          return ""
        elseif mode:sub(1, 1) == "R" then
          return ""
        elseif mode:sub(1, 1) == "v" or mode:sub(1, 1) == "V" or mode:sub(1, 1) == "\22" then
          return ""
        elseif mode:sub(1, 2) == "no" then
          return operator_icons[vim.v.operator] or ""
        end
        return ""
      end

      local function line_number(args)
        local text
        if args.relnum ~= 0 then
          text = builtin.lnumfunc(args)
          return "%#LineNr#" .. text .. "%*"
        end

        local mode = vim.api.nvim_get_mode().mode
        if mode == "n" and not _G._my_statuscolumn_operator then
          local number = tostring(args.lnum)
          -- Current number ends one cell before the other rows' numbers.
          local pad = math.max(0, args.nuw - #number - 1)
          text = "%=" .. string.rep(" ", pad) .. number .. " "
          return "%#LineNr#" .. text .. "%*"
        end

        local scene = mode_style.get_scene(mode, _G._my_statuscolumn_operator)
        local icon = current_mode_icon()
        local pad = math.max(0, args.nuw - vim.fn.strdisplaywidth(icon) - 1)
        text = "%=" .. string.rep(" ", pad) .. icon .. " "
        return "%#StatusColMode" .. scene .. "#" .. text .. "%*"
      end

      local function separator(args)
        local hl
        if args.relnum == 0 then
          local scene = mode_style.get_scene(vim.api.nvim_get_mode().mode, _G._my_statuscolumn_operator)
          hl = scene == "normal" and "LineNr" or "StatusColMode" .. scene
        else
          hl = "LineNr"
        end
        local mark = args.relnum == 0 and "❯" or " "
        return "%#" .. hl .. "#" .. mark .. "%*"
      end

      require("statuscol").setup({
        -- Snacks Dashboard や特殊バッファでは現在行アイコンを表示しない。
        ft_ignore = { "snacks_dashboard" },
        bt_ignore = { "nofile", "prompt", "quickfix", "terminal" },
        relculright = true,
        segments = {
          { text = { "%s" }, click = "v:lua.ScSa" },
          { text = { line_number }, click = "v:lua.ScLa" },
          { text = { separator } },
        },
      })

      local function redraw_statuscolumn(immediate)
        local function refresh()
          vim.cmd("redrawstatus")
          -- r waits for a literal character and does not run scheduled callbacks.
          -- Flush Incline's debounce before entering that wait.
          local manager = package.loaded["incline.manager"]
          if manager then manager.update:immediate({ refresh = true }) end
          vim.cmd("redraw")
        end
        if immediate then refresh() else vim.schedule(refresh) end
      end

      -- r is a Normal command, so track its literal-character wait explicitly.
      vim.on_key(function(key)
        if _G._my_statuscolumn_operator == "r" then
          _G._my_statuscolumn_operator = nil
          _G._my_statuscolumn_operator_seq = _G._my_statuscolumn_operator_seq + 1
          local modes = package.loaded.modes
          if modes then modes.highlight("default") end
          redraw_statuscolumn(true)
          return
        end
        if vim.api.nvim_get_mode().mode ~= "n" or not operator_icons[key] then
          return
        end
        _G._my_statuscolumn_operator = key
        _G._my_statuscolumn_operator_seq = _G._my_statuscolumn_operator_seq + 1
        local seq = _G._my_statuscolumn_operator_seq
        if key == "r" then
          require("modes").highlight("insert")
        end
        redraw_statuscolumn(true)
        if key == "r" then return end
        vim.defer_fn(function()
          if _G._my_statuscolumn_operator_seq == seq and vim.api.nvim_get_mode().mode == "n" then
            _G._my_statuscolumn_operator = nil
            redraw_statuscolumn()
          end
        end, 600)
      end, vim.api.nvim_create_namespace("statuscolumn_operator_icon"))

      vim.api.nvim_create_autocmd("ModeChanged", {
        callback = function()
          if vim.api.nvim_get_mode().mode == "n" and _G._my_statuscolumn_operator then
            _G._my_statuscolumn_operator = nil
            _G._my_statuscolumn_operator_seq = _G._my_statuscolumn_operator_seq + 1
            redraw_statuscolumn()
          end
        end,
        desc = "Normal モード復帰時にoperatorアイコンを解除",
      })
    end,
  },
}
