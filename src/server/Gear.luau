--!strict
-- gloves and trunks for R6 fighters, glove meshes in BoxingGear.GloveParts
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = {}

-- real catalog trunks: J. Parker Red White & Gold Boxing Shorts (Ro-Boxing Apparel)
Gear.TrunksTemplate = "http://www.roblox.com/asset/?id=17137655469"

-- each glove is separate mesh parts welded flat onto the arm, no rotation, so it
-- follows the arm exactly. offsets are in arm space, the hand end is -Y
local PARTS: { { Name: string, Size: Vector3, Offset: CFrame, Lace: boolean, Box: boolean? } } = {
	{ Name = "Glove", Size = Vector3.new(1.12, 1.06, 1.12), Offset = CFrame.new(0, -0.74, 0), Lace = false },
	{
		Name = "Thumb",
		Size = Vector3.new(0.32, 0.62, 0.42),
		Offset = CFrame.new(0.5, -0.6, -0.18) * CFrame.Angles(0, 0, -0.35),
		Lace = false,
	},
	-- the cuff and its bands are square blocks, round ones let the corners of the blocky arm poke through
	{ Name = "Base", Size = Vector3.new(1.08, 0.42, 1.08), Offset = CFrame.new(0, -0.1, 0), Lace = false, Box = true },
	{
		Name = "Band_Upper",
		Size = Vector3.new(1.1, 0.08, 1.1),
		Offset = CFrame.new(0, 0.05, 0),
		Lace = true,
		Box = true,
	},
	{
		Name = "Band_Down",
		Size = Vector3.new(1.1, 0.08, 1.1),
		Offset = CFrame.new(0, -0.2, 0),
		Lace = true,
		Box = true,
	},
}
Gear.Leather = Color3.fromRGB(150, 18, 18)
Gear.Lace = Color3.fromRGB(235, 235, 228)

-- leather defaults to red, the shop's Glove Colors pass picks others
function Gear.gloves(model: Model, leather: Color3?)
	local gear = ReplicatedStorage:FindFirstChild("BoxingGear")
	local meshes = gear and gear:FindFirstChild("GloveParts")
	if not meshes then
		warn("[Gear] ReplicatedStorage.BoxingGear.GloveParts is missing")
		return
	end
	for _, armName in { "Left Arm", "Right Arm" } do
		local arm = model:FindFirstChild(armName)
		if not (arm and arm:IsA("BasePart")) then
			continue
		end
		local old = arm:FindFirstChild("Glove")
		if old then
			old:Destroy()
		end
		local glove = Instance.new("Model")
		glove.Name = "Glove"
		-- thumb sits on the body side, which is +X on the left arm and -X on the right
		local mirror = if armName == "Right Arm" then -1 else 1
		for _, info in PARTS do
			local source = meshes:FindFirstChild(info.Name)
			if not (source and source:IsA("BasePart")) then
				continue
			end
			local p: BasePart = if info.Box then Instance.new("Part") else source:Clone()
			p.Name = info.Name
			p.Size = info.Size
			p.Color = if info.Lace then Gear.Lace else (leather or Gear.Leather)
			p.Material = Enum.Material.SmoothPlastic
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			local offset = info.Offset
			if mirror < 0 then
				local x, y, z = offset:ToOrientation()
				offset = CFrame.new(-offset.X, offset.Y, offset.Z) * CFrame.fromOrientation(x, -y, -z)
			end
			p.CFrame = arm.CFrame * offset
			local weld = Instance.new("Weld")
			weld.Part0 = arm
			weld.Part1 = p
			weld.C0 = offset
			weld.Parent = p
			p.Parent = glove
		end
		glove.Parent = arm
	end
end

-- boxers fight shirtless with no hats or gear from their avatar. hair stays so people still
-- look like themselves
function Gear.strip(model: Model)
	for _, c in model:GetChildren() do
		if c:IsA("Accessory") then
			if c.AccessoryType ~= Enum.AccessoryType.Hair then
				c:Destroy()
			end
		elseif c:IsA("Shirt") or c:IsA("ShirtGraphic") then
			c:Destroy()
		end
	end
end

function Gear.trunks(model: Model)
	for _, c in model:GetChildren() do
		if c:IsA("Pants") then
			c:Destroy()
		end
	end
	local pants = Instance.new("Pants")
	pants.Name = "BoxingTrunks"
	pants.PantsTemplate = Gear.TrunksTemplate
	pants.Parent = model
end

return Gear
