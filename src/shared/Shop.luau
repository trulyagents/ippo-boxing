--!strict
-- passes, products (made with tools/monetize.py) and glove colors. the server checks ownership itself
local Shop = {}

Shop.Passes = {
	GloveColors = 2036788994,
	KOEffect = 2039758750,
	VIP = 2039794751,
} :: { [string]: number }
Shop.Products = {
	StatRespec = 3720142839,
} :: { [string]: number }

-- red is everyone's, the rest come with GloveColors
Shop.Gloves = {
	{ Name = "Red", Color = Color3.fromRGB(150, 18, 18) },
	{ Name = "Blue", Color = Color3.fromRGB(25, 60, 150) },
	{ Name = "Black", Color = Color3.fromRGB(28, 26, 26) },
	{ Name = "Gold", Color = Color3.fromRGB(196, 150, 40) },
	{ Name = "Pink", Color = Color3.fromRGB(214, 90, 150) },
}

function Shop.glove(name: string): { Name: string, Color: Color3 }?
	for _, g in Shop.Gloves do
		if g.Name == name then
			return g
		end
	end
	return nil
end

Shop.VIPDailyBonus = 1 -- extra stat points on every daily streak reward

return Shop
