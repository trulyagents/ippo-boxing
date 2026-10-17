--!strict
-- Boxing gloves and trunks for R6 fighters. Glove meshes come from models/glove (Blender),
-- imported into ReplicatedStorage.BoxingGear.GloveParts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = {}

-- real catalog trunks: J. Parker Red White & Gold Boxing Shorts (Ro-Boxing Apparel)
Gear.TrunksTemplate = "http://www.roblox.com/asset/?id=17137655469"

-- each glove is separate mesh parts welded flat onto the arm, no rotation, so it
-- follows the arm exactly. offsets are in arm space, the hand end is -Y
local PARTS = {
	{ Name = "Glove", Size = Vector3.new(1.12, 1.06, 1.12), Offset = CFrame.new(0, -0.74, 0), Lace = false },
	{ Name = "Thumb", Size = Vector3.new(0.32, 0.62, 0.42), Offset = CFrame.new(0.5, -0.6, -0.18) * CFrame.Angles(0, 0, -0.35), Lace = false },
	{ Name = "Base", Size = Vector3.new(1.06, 0.42, 1.06), Offset = CFrame.new(0, -0.1, 0), Lace = false },
	{ Name = "Band_Upper", Size = Vector3.new(1.09, 0.08, 1.09), Offset = CFrame.new(0, 0.05, 0), Lace = true },
	{ Name = "Band_Down", Size = Vector3.new(1.09, 0.08, 1.09), Offset = CFrame.new(0, -0.2, 0), Lace = true },
}
Gear.Leather = Color3.fromRGB(150, 18, 18)
Gear.Lace = Color3.fromRGB(235, 235, 228)

function Gear.gloves(model: Model)
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
			local p = source:Clone()
			p.Size = info.Size
			p.Color = if info.Lace then Gear.Lace else Gear.Leather
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
