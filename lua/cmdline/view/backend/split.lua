---@param opts? NoiceViewOptions
return function(opts)
  opts.type = "split"
  return require("cmdline.view.nui")(opts)
end
