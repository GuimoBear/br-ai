local files = {
  "lua/src/data/monsters.lua",
  "lua/src/bt/decorators.lua",
  "lua/src/bt/tree.lua",
  "lua/bootstrap.lua",
}
for _,f in ipairs(files) do
  local ok, err = loadfile(f)
  print(f, ok and "OK" or ("ERR: "..tostring(err)))
end
