--!strict
-- Puts boxing gloves on an R6 fighter. The glove mesh lives in ReplicatedStorage.BoxingGear
-- (made in Studio), sized to wrap the end of an R6 arm.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = {}

-- real catalog trunks: J. Parker Red White & Gold Boxing Shorts (Ro-Boxing Apparel)
Gear.TrunksTemplate = "http://www.roblox.com/asset/?id=17137655469"

function Gear.gloves(model: Model)
	local template = ReplicatedStorage:FindFirstChild("BoxingGear")
	local glove = template and template:FindFirstChild("Glove")
	if not (glove and glove:IsA("BasePart")) then
		warn("[Gear] ReplicatedStorage.BoxingGear.Glove is missing")
		return
	end
	local old = model:FindFirstChild("Gloves")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Gloves"
	for _, armName in { "Left Arm", "Right Arm" } do
		local arm = model:FindFirstChild(armName)
		if arm and arm:IsA("BasePart") then
			local g = glove:Clone()
			g.Name = armName .. "Glove"
			-- cuff toward the elbow, fist at the end of the arm, thumb toward the body
			local spin = if armName == "Left Arm" then 90 else -90
			g.CFrame = arm.CFrame * CFrame.new(0, -0.78, 0) * CFrame.Angles(math.pi, 0, 0) * CFrame.Angles(0, math.rad(spin), 0)
			g.Anchored = false
			g.Massless = true
			g.CanCollide = false
			g.CanQuery = false
			g.CanTouch = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = arm
			weld.Part1 = g
			weld.Parent = g
			g.Parent = folder
		end
	end
	folder.Parent = model
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
