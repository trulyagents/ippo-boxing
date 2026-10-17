local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local dir = process.args[1]
local bad = 0
for _, name in fs.readDir(dir) do
	local ok, err = pcall(luau.compile, fs.readFile(dir .. "/" .. name))
	if not ok then bad += 1; print("FAIL", name, err) end
end
print("checked, failures:", bad)
