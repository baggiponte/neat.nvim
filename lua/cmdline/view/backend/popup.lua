---@param opts? NoiceViewOptions
return function(opts)
  opts.type = "popup"
  return require("cmdline.view.nui")(opts)
end
