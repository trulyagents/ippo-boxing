-- run in studio (command bar / mcp execute_luau). change ROOT to the gui to dump, it returns
-- "<length>|<json>". save that to a file and run tools/gui_to_rbxmx.py on it.
local ROOT = game.StarterGui.BoxingHUD
local HS = game:GetService("HttpService")
local PROPS = { "Name", "AnchorPoint", "Position", "Size", "Rotation", "Visible", "ZIndex", "LayoutOrder", "BackgroundColor3",
	"BackgroundTransparency", "BorderSizePixel", "ClipsDescendants", "Image", "ImageColor3", "ImageTransparency", "ScaleType",
	"Text", "TextColor3", "TextScaled", "TextSize", "TextTransparency", "TextStrokeColor3", "TextStrokeTransparency",
	"TextXAlignment", "TextYAlignment", "FontFace", "GroupTransparency", "AspectRatio", "DominantAxis", "AspectType", "MinSize",
	"MaxSize", "MaxTextSize", "MinTextSize", "Padding", "SortOrder", "FillDirection", "HorizontalAlignment", "VerticalAlignment",
	"CornerRadius", "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom", "Scale", "Color", "Thickness", "ApplyStrokeMode",
	"Transparency", "ResetOnSpawn", "IgnoreGuiInset", "ZIndexBehavior", "DisplayOrder", "AutoButtonColor", "Enabled" }
local function enc(v)
	local t = typeof(v)
	if t == "UDim2" then
		return { "UDim2", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then
		return { "UDim", v.Scale, v.Offset }
	elseif t == "Vector2" then
		return { "Vector2", v.X, v.Y }
	elseif t == "Color3" then
		return { "Color3", v.R, v.G, v.B }
	elseif t == "EnumItem" then
		return { "Enum", v.Value }
	elseif t == "Font" then
		return { "Font", v.Family, v.Weight.Value, v.Style.Name }
	elseif t == "boolean" or t == "number" or t == "string" then
		return { t, v }
	end
	return nil
end
local nodes = {}
local id = 0
local function walk(inst, parent)
	id += 1
	local me = id
	local props = {}
	for _, p in PROPS do
		local ok, v = pcall(function()
			return (inst :: any)[p]
		end)
		if ok and v ~= nil then
			props[p] = enc(v)
		end
	end
	table.insert(nodes, { id = me, parent = parent, class = inst.ClassName, props = props })
	for _, c in inst:GetChildren() do
		walk(c, me)
	end
end
walk(ROOT, 0)
local s = HS:JSONEncode(nodes)
return #s .. "|" .. s
