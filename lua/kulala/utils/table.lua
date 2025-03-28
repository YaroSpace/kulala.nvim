local M = {}

M.slice = function(tbl, first, last)
  local sliced = {}

  -- Adjust for out-of-bound indices
  first = first or 1
  last = last or #tbl
  if first < 1 then first = 1 end
  if last > #tbl then last = #tbl end

  -- Extract the slice
  for i = first, last do
    sliced[#sliced + 1] = tbl[i]
  end

  return sliced
end

M.remove_keys = function(tbl, keys)
  vim.iter(keys):each(function(key)
    tbl[key] = nil
  end)
end

--- Merge table 2 into table 1, keeping existing keys
M.merge = function(tbl_1, tbl_2)
  vim.iter(tbl_2):each(function(k, v)
    if not tbl_1[k] then tbl_1[k] = v end
  end)
end

return M
