-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: module paths renamed from noice to cmdline.
---@param opts? NoiceViewOptions
return function(opts)
  opts.type = "popup"
  return require("cmdline.view.nui")(opts)
end
