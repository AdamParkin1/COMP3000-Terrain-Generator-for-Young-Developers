-- Statics
local RS = game:GetService("ReplicatedStorage")

local center = Vector3.new(0,20,0)		-- The center of the terrain. (Default: Vector3.new(0,20,0))


--	Custom settings
local MASTER_XLENGTH = 1024
local MASTER_ZLENGTH = 1024
local MASTER_LOW_CONSTRAINT = 0
local MASTER_HIGH_CONSTRAINT = 150
local MASTER_SPACING = 16
local MASTER_SEED = 2
local MASTER_BIOME = "forest"

local rng = Random.new(MASTER_SEED)
local treeChanceMultiplier = 1  --  Trees selected to grow normally must also then pass this chance test.

-- Noise generation settings

--------

-- PerlinNoise2D

local PerlinNoise2D = {
	s = {},		-- settings
	p = {},		-- permutation table

	gx = {},		-- gradient table
	gy = {}		-- gradient table
}

function PerlinNoise2D:noise(x,y)
	local p = self.p
	local gx = self.gx
	local gy = self.gy

	-- Compute the integer positions of the four surrounding points
	local qx0 = math.floor(x)
	local qx1 = qx0 + 1
	local qy0 = math.floor(y)
	local qy1 = qy0 + 1
	
	-- Permutate values to get indices to use with the gradient look-up tables
	local q00 = p[(qy0 + p[qx0])]
	local q01 = p[(qy0 + p[qx1])]
	local q10 = p[(qy1 + p[qx0])]
	local q11 = p[(qy1 + p[qx1])]
	
	-- Computing vectors from the four points to the input point
	local tx0 = x - math.floor(x)
	local tx1 = tx0 - 1
	local ty0 = y - math.floor(y)
	local ty1 = ty0 - 1
	
	-- Compute the dot product between the vectors and gradients
	local v00 = gx[q00]*tx0 + gy[q00]*ty0
	local v01 = gx[q01]*tx1 + gy[q01]*ty0
	local v10 = gx[q10]*tx0 + gy[q10]*ty1
	local v11 = gx[q11]*tx1 + gy[q11]*ty1
	
	-- Do the bi-cubic interpolation to get the final value
	local wx = (3 - 2*tx0)*tx0*tx0		-- 3t^2 - 2t^3
	local v0 = v00 - wx*(v00 - v01)
	local v1 = v10 - wx*(v10 - v11)
	
	local wy = (3 - 2*ty0)*ty0*ty0		-- 3t^2 - 2t^3
	local v = v0 - wy*(v0 - v1)
	
	return v
end

function PerlinNoise2D:getValue(x,y)
	local per = self.s.persistence
	local amp = 1
	local frq = self.s.frequency
	local total = 0

	for i = 0,self.s.octaves-1 do
		amp = per^i
		frq = frq^i

		total = total + self:noise(x*frq,y*frq)*amp
	end

	return total*self.s.amplitude
end

function PerlinNoise2D:init(us)
	local this = {}
	setmetatable(this,self)
	self.__index = self
	
	local s = this.s
	local p = this.p
	local gx = this.gx
	local gy = this.gy
	
	-- Attach local settings
	for i,v in pairs(us) do
		print(i,v)
		s[i] = v
	end
	
	-- Fill the permutation table
	for i = 0,255 do
		p[i] = i
	end

	-- Randomly sort the permutation table
	for i = 0,255 do
		local j = rng:NextInteger(1,255)
		p[i],p[j] = p[j],p[i]
	end

	-- Allow indices in p to wrap around
	p.__index = function(t,k)
			return rawget(t,k%255)
		end
	setmetatable(p,p)

	-- Generate the gradient look-up tables (values between -1 and 1, inclusive)
	for i = 0,255 do
		gx[i] = rng:NextNumber() + rng:NextNumber() - 1 rng:NextNumber()
		gy[i] = rng:NextNumber() + rng:NextNumber() - 1
	end

	return this
end

--------

-- DrawTriangle

function spawnTrianglePart(parent, us)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.BottomSurface = 0
	p.TopSurface = 0
	p.formFactor = "Custom"
	p.Size = Vector3.new(1,1,1)
	p.Parent = parent or game.Workspace

	p.BrickColor = (us.colour) and BrickColor.new(us.colour) or BrickColor.new(194)
	p.Material = (us.material) and us.material or Enum.Material.Plastic

	return p
end

function drawTriangle(a,b,c,parent,us)
	-- split triangle into two right angles on longest edge:
	local len_AB = (b - a).magnitude
	local len_BC = (c - b).magnitude
	local len_CA = (a - c).magnitude

	if (len_AB > len_BC) and (len_AB > len_CA) then
		a,c = c,a
		b,c = c,b
	elseif (len_CA > len_AB) and (len_CA > len_BC) then
		a,b = b,a
		b,c = c,b
	end

	local dot = (a - b):Dot(c - b)
	local split = b + (c-b).unit*dot/(c - b).magnitude

	-- get triangle sizes:
	local xA = 0.2
	local yA = (split - a).magnitude
	local zA = (split - b).magnitude

	local xB = 0.2
	local yB = (split - a).magnitude
	local zB = (split - c).magnitude

	-- get unit directions:
	local diry = (a - split).unit
	local dirz = (c - split).unit
	local dirx = diry:Cross(dirz).unit

	-- get triangle centers:
	local posA = split + diry*yA/2 - dirz*zA/2
	local posB = split + diry*yB/2 + dirz*zB/2

	-- place parts:
	local partA = spawnTrianglePart(parent,us)
	partA.Name = "TrianglePart"
	partA.Size = Vector3.new(xA,yA,zA)
	partA.CFrame = CFrame.new(posA.x,posA.y,posA.z, dirx.x,diry.x,dirz.x, dirx.y,diry.y,dirz.y, dirx.z,diry.z,dirz.z)*CFrame.new(-0.1,0,0)
	--partA.Color = Color3.fromRGB(255*(partA.Position.Y/100), 255*(partA.Position.Y/100), 255*(partA.Position.Y/100))

	dirx = dirx * -1
	dirz = dirz * -1

	local partB = spawnTrianglePart(parent,us)
	partB.Name = "TrianglePart"
	partB.Size = Vector3.new(xB,yB,zB)
	partB.CFrame = CFrame.new(posB.x,posB.y,posB.z, dirx.x,diry.x,dirz.x, dirx.y,diry.y,dirz.y, dirx.z,diry.z,dirz.z)*CFrame.new(0.1,0,0)
	--partB.Color = Color3.fromRGB(255*(partB.Position.Y/100), 255*(partB.Position.Y/100), 255*(partB.Position.Y/100))
end

--------

local model = Instance.new("Model",game.Workspace)
model.Name = "Terrain"
local treeModel = Instance.new("Model",game.Workspace)
treeModel.Name = "tree"

-- here?

function CreateTerrain()
	rng = Random.new(MASTER_SEED)
	local masterGeneration = {
		["forest"] = {
			["Terrain"] = {
				["xLength"] = MASTER_XLENGTH,		-- The length of the terrain along global X. (Default: 2048)
				["zLength"] = MASTER_ZLENGTH,		-- The length of the terrain along global Z. (Default: 2048)
				["lowConstraint"] = MASTER_LOW_CONSTRAINT,		-- The lowest the Y value can go
				["highConstraint"] = MASTER_HIGH_CONSTRAINT,		-- The highest the Y valued can go

				["spacing"] = MASTER_SPACING,			-- The distance between terrain segments. (Default: 64)

				["randomseed"] = MASTER_SEED ,	-- The terrain's random seed (same seed = same terrain). (Default: math.floor(tick()))

				["persistence"] = 3.5	,	-- Increasing this makes for steeper inclines. (Default: 2)
				["amplitude"] = 45,			-- Increasing this makes the highs higher and the lows lower. (Default: 20)
				["frequency"] = 0.1,			-- Increasing this adds more highs and lows. (Default: 0.5)

				["octaves"] = 2,				-- Increasing this adds turbulence. (Default: 2)
				["wavelength"] = 300,		-- Increasing this flattens everything out. (Default: 100)

				["colour"] = "Grime",	-- The colour of each terrain segment. (Default: Grime)
				["material"] = "Plastic"		-- The material of each terrain segment. (Default: Grass)
			},

			["Decorations"] = {
				["xLength"] = MASTER_XLENGTH,		-- The length of the terrain along global X. (Default: 2048)
				["zLength"] = MASTER_ZLENGTH,		-- the length of the terrain along global Z. (Default: 2048)
				["lowConstraint"] = 0,
				["highConstraint"] = 100,

				["spacing"] = MASTER_SPACING*2,			-- The distance between terrain segments. (Default: 64)

				["randomseed"] = MASTER_SEED,	-- The terrain's random seed (same seed = same terrain). (Default: math.floor(tick()))

				["persistence"] = 4,	-- Increasing this makes for steeper inclines. (Default: 2)
				["amplitude"] = 100,			-- Increasing this makes the highs higher and the lows lower. (Default: 20)
				["frequency"] = 1,			-- Increasing this adds more highs and lows. (Default: 0.5)

				["octaves"] = 2,				-- Increasing this adds turbulence. (Default: 2)
				["wavelength"] = 250,		-- Increasing this flattens everything out. (Default: 100)

				["colour"] = "Brown",	-- The colour of each terrain segment. (Default: Grime)
				["material"] = "Plastic"		-- The material of each terrain segment. (Default: Grass)
			}
		},

		["desert"] = {
			["Terrain"] = {
				["xLength"] = MASTER_XLENGTH,		-- The length of the terrain along global X. (Default: 2048)
				["zLength"] = MASTER_ZLENGTH,		-- The length of the terrain along global Z. (Default: 2048)
				["lowConstraint"] = MASTER_LOW_CONSTRAINT,		-- The lowest the Y value can go
				["highConstraint"] = MASTER_HIGH_CONSTRAINT,		-- The highest the Y valued can go

				["spacing"] = MASTER_SPACING,			-- The distance between terrain segments. (Default: 64)

				["randomseed"] = MASTER_SEED ,	-- The terrain's random seed (same seed = same terrain). (Default: math.floor(tick()))

				["persistence"] = 3	,	-- Increasing this makes for steeper inclines. (Default: 2)
				["amplitude"] = 35,			-- Increasing this makes the highs higher and the lows lower. (Default: 20)
				["frequency"] = 0.5,			-- Increasing this adds more highs and lows. (Default: 0.5)

				["octaves"] = 2,				-- Increasing this adds turbulence. (Default: 2)
				["wavelength"] = 500,		-- Increasing this flattens everything out. (Default: 100)

				["colour"] = "Pastel brown",	-- The colour of each terrain segment. (Default: Grime)
				["material"] = "Sand"		-- The material of each terrain segment. (Default: Grass)
			},

			["Decorations"] = {
				["xLength"] = MASTER_XLENGTH,		-- The length of the terrain along global X. (Default: 2048)
				["zLength"] = MASTER_ZLENGTH,		-- the length of the terrain along global Z. (Default: 2048)
				["lowConstraint"] = 0,
				["highConstraint"] = 0,

				["spacing"] = MASTER_SPACING*2,			-- The distance between terrain segments. (Default: 64)

				["randomseed"] = MASTER_SEED,	-- The terrain's random seed (same seed = same terrain). (Default: math.floor(tick()))

				["persistence"] = 4,	-- Increasing this makes for steeper inclines. (Default: 2)
				["amplitude"] = 100,			-- Increasing this makes the highs higher and the lows lower. (Default: 20)
				["frequency"] = 1,			-- Increasing this adds more highs and lows. (Default: 0.5)

				["octaves"] = 2,				-- Increasing this adds turbulence. (Default: 2)
				["wavelength"] = 250,		-- Increasing this flattens everything out. (Default: 100)

				["colour"] = "Brown",	-- The colour of each terrain segment. (Default: Grime)
				["material"] = "Plastic"		-- The material of each terrain segment. (Default: Grass)
			}
		},

		["tundra"] = {
			["Terrain"] = {
				["xLength"] = MASTER_XLENGTH,		-- The length of the terrain along global X. (Default: 2048)
				["zLength"] = MASTER_ZLENGTH,		-- The length of the terrain along global Z. (Default: 2048)
				["lowConstraint"] = MASTER_LOW_CONSTRAINT,		-- The lowest the Y value can go
				["highConstraint"] = MASTER_HIGH_CONSTRAINT,		-- The highest the Y valued can go

				["spacing"] = MASTER_SPACING,			-- The distance between terrain segments. (Default: 64)

				["randomseed"] = MASTER_SEED ,	-- The terrain's random seed (same seed = same terrain). (Default: math.floor(tick()))

				["persistence"] = 5	,	-- Increasing this makes for steeper inclines. (Default: 2)
				["amplitude"] = 55,			-- Increasing this makes the highs higher and the lows lower. (Default: 20)
				["frequency"] = 0.75,			-- Increasing this adds more highs and lows. (Default: 0.5)

				["octaves"] = 2.5,				-- Increasing this adds turbulence. (Default: 2)
				["wavelength"] = 300,		-- Increasing this flattens everything out. (Default: 100)

				["colour"] = "Fog",	-- The colour of each terrain segment. (Default: Grime)
				["material"] = "Snow"		-- The material of each terrain segment. (Default: Grass)
			},

			["Decorations"] = {
				["xLength"] = MASTER_XLENGTH,		-- The length of the terrain along global X. (Default: 2048)
				["zLength"] = MASTER_ZLENGTH,		-- the length of the terrain along global Z. (Default: 2048)
				["lowConstraint"] = 0,
				["highConstraint"] = 5,

				["spacing"] = MASTER_SPACING*2,			-- The distance between terrain segments. (Default: 64)

				["randomseed"] = MASTER_SEED,	-- The terrain's random seed (same seed = same terrain). (Default: math.floor(tick()))

				["persistence"] = 4,	-- Increasing this makes for steeper inclines. (Default: 2)
				["amplitude"] = 100,			-- Increasing this makes the highs higher and the lows lower. (Default: 20)
				["frequency"] = 1,			-- Increasing this adds more highs and lows. (Default: 0.5)

				["octaves"] = 2,				-- Increasing this adds turbulence. (Default: 2)
				["wavelength"] = 250,		-- Increasing this flattens everything out. (Default: 100)

				["colour"] = "Brown",	-- The colour of each terrain segment. (Default: Grime)
				["material"] = "Plastic"		-- The material of each terrain segment. (Default: Grass)
			}
		}
	}


local terrain2DSettings = masterGeneration[MASTER_BIOME].Terrain
local tree2DSettings = masterGeneration[MASTER_BIOME].Decorations
local treeModels = script[MASTER_BIOME].Trees:GetChildren()
local bushModels = script[MASTER_BIOME].Bushes:GetChildren()

print("TriangleTerrain will use "..((terrain2DSettings.xLength/terrain2DSettings.spacing)*(terrain2DSettings.zLength/terrain2DSettings.spacing)*4).." parts.")

-- Generate Height Map
print("TriangleTerrain: Generating...")

local terrain2D = PerlinNoise2D:init(terrain2DSettings)		-- create new 2D noise map
local terrain = {}



for z = 0,terrain2DSettings.zLength,terrain2DSettings.spacing do
	local t = {}

	for x = 0,terrain2DSettings.xLength,terrain2DSettings.spacing do
		local n = terrain2D:getValue(x/terrain2DSettings.wavelength,z/terrain2DSettings.wavelength)

		local a = center.X + (x - terrain2DSettings.xLength/2)
		local b = math.max(terrain2DSettings.lowConstraint,center.Y + n)
		b = math.min(terrain2DSettings.highConstraint,b)
		local c = center.Z + (z - terrain2DSettings.zLength/2)
		
		--[[local nodePoint = Instance.new("Part")
		nodePoint.Anchored = true
		nodePoint.Size = Vector3.new(4,4,4)
		nodePoint.Shape = "Ball"
		nodePoint.Position = Vector3.new(a,b,c)
		nodePoint.Material = Enum.Material.Neon
		nodePoint.Color = Color3.fromRGB(255,0,0)
		nodePoint.Parent = workspace]]
		
		table.insert(t,Vector3.new(a,b,c))
	end

	table.insert(terrain,t)
end

-- Draw Terrain

print("TriangleTerrain: Drawing...")

for z = 1,#terrain-1 do
	for x = 1,#terrain[z]-1 do
		local r = terrain[z][x]
		local s = terrain[z][x+1]
		local t = terrain[z+1][x]

		drawTriangle(r,s,t,model,terrain2DSettings)

		local u = terrain[z+1][x+1]
		local v = terrain[z+1][x]
		local w = terrain[z][x+1]

		drawTriangle(u,v,w,model,terrain2DSettings)
	end
end

print("TriangleTerrain: Done")


print("TreeMap: Generating...")

local tree2D = PerlinNoise2D:init(tree2DSettings)	
local trees = {}


for z = 0,tree2DSettings.zLength,tree2DSettings.spacing do
	local t = {}

	for x = 0,tree2DSettings.xLength,tree2DSettings.spacing do
		local n = tree2D:getValue(x/tree2DSettings.wavelength,z/tree2DSettings.wavelength)
		
		local xPos = center.X + (x - terrain2DSettings.xLength/2)
		local zPos = center.Z + (z - terrain2DSettings.zLength/2)
		
		local probability = math.max(tree2DSettings.lowConstraint,center.Y + n)
		probability = math.min(tree2DSettings.highConstraint,probability)
		
		if probability * treeChanceMultiplier >=rng:NextInteger(0,100) then
			--TODO: Place tree 
			--[[local newPart = Instance.new("Part",treeModel)
			newPart.Anchored = true
			newPart.BrickColor = BrickColor.new(tree2DSettings.colour)
			newPart.Size = Vector3.new(1,200,1)
			newPart.Position=Vector3.new(xPos,0,zPos)]]

			local newTreeModel = treeModels[rng:NextInteger(1,#treeModels)]:Clone()
			
			
			local rayOrigin = newTreeModel.PrimaryPart.Position + Vector3.new(xPos,400,zPos)
			local rayDirection = Vector3.new(0,-1000,0)

			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {newTreeModel.Parent,treeModel}
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

			if raycastResult then
				local hitPos = raycastResult.Position
				newTreeModel:SetPrimaryPartCFrame(CFrame.new(hitPos + Vector3.new(0, newTreeModel.PrimaryPart.Size.Y/2-0.3, 0) ) )
			end

			newTreeModel:SetPrimaryPartCFrame(newTreeModel.PrimaryPart.CFrame * CFrame.Angles(0,math.rad(rng:NextInteger(1,359)), 0 ) )
			newTreeModel.Parent = treeModel
			
		elseif probability* treeChanceMultiplier*1.25>=rng:NextInteger(0,100) then
			local newBushModel = treeModels[rng:NextInteger(1,#bushModels)]:Clone()
			
			local rayOrigin = newBushModel.PrimaryPart.Position + Vector3.new(xPos,400,zPos)
			local rayDirection = Vector3.new(0,-1000,0)

			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {newBushModel.Parent,treeModel}
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

			if raycastResult then
				local hitPos = raycastResult.Position
				newBushModel:SetPrimaryPartCFrame(CFrame.new(hitPos + Vector3.new(0, newBushModel.PrimaryPart.Size.Y/2, 0) ) )
			end

			newBushModel:SetPrimaryPartCFrame(newBushModel.PrimaryPart.CFrame * CFrame.Angles(0,math.rad(rng:NextInteger(1,359)), 0 ) )
			newBushModel.Parent = treeModel
		end

	end
end
-- VVVV TO DRAW TREEMAP VVVV
--[[
for z = 0,tree2DSettings.zLength,tree2DSettings.spacing do
	local t = {}

	for x = 0,tree2DSettings.xLength,tree2DSettings.spacing do
		local n = tree2D:getValue(x/tree2DSettings.wavelength,z/tree2DSettings.wavelength)

		local a = center.X + (x - tree2DSettings.xLength/2)
		local b = math.max(tree2DSettings.lowConstraint,center.Y + n)
		b = math.min(tree2DSettings.highConstraint,b)
		local c = center.Z + (z - tree2DSettings.zLength/2)

		table.insert(t,Vector3.new(a,b,c))
	end

	table.insert(trees,t)
end

print("TreeMap: Drawing...")

for z = 1,#trees-1 do
	for x = 1,#trees[z]-1 do
		local r = trees[z][x]
		local s = trees[z][x+1]
		local t = trees[z+1][x]

		drawTriangle(r,s,t,treeModel,tree2DSettings)

		local u = trees[z+1][x+1]
		local v = trees[z+1][x]
		local w = trees[z][x+1]

		drawTriangle(u,v,w,treeModel,tree2DSettings)
	end
end

print("TreeMap: Done")]]
	
end
	
RS.GenerateTerrain.OnServerEvent:Connect(function(player, options)
	if options["xLength"] ~= "" then MASTER_XLENGTH = tonumber(options["xLength"]) end
	if options["yLength"] ~= "" then MASTER_ZLENGTH = tonumber(options["yLength"]) end
	if options["minHeight"] ~= "" then MASTER_LOW_CONSTRAINT = tonumber(options["minHeight"]) end
	if options["maxHeight"] ~= "" then MASTER_HIGH_CONSTRAINT = tonumber(options["maxHeight"]) end
	if options["tileSize"] ~= "" then MASTER_SPACING = tonumber(options["tileSize"]) end
	if options["seed"] ~= "" then MASTER_SEED = tonumber(options["seed"]) end
	if options["biome"] ~= "" then MASTER_BIOME = tostring(options["biome"]) end
	if options["treeMultiplier"] ~= "" then treeChanceMultiplier = tonumber(options["treeMultiplier"]) end
	
	model:ClearAllChildren()
	treeModel:ClearAllChildren()
	
	CreateTerrain()
end)
