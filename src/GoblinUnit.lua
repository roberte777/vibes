-- GoblinUnit Class
local GoblinUnit = {}
GoblinUnit.__index = GoblinUnit

-- Unit types and their properties
local unitTypes = {
    warrior = {
        name = "Warrior Goblin",
        description = "A sturdy goblin with a shield and sword",
        cost = 10,
        health = 200,
        damage = 20,
        range = 1,
        color = {0.2, 0.7, 0.3, 1}, -- Green
        size = 25,
        projectileColor = {0.8, 0.8, 0.8, 1}, -- Silver for sword slash
        projectileSpeed = 120,
        projectileSize = 5
    },
    archer = {
        name = "Archer Goblin",
        description = "A nimble goblin with a bow and arrow",
        cost = 10, 
        health = 120,
        damage = 10,
        range = 3,
        color = {0.8, 0.6, 0.2, 1}, -- Orange/Brown
        size = 22,
        projectileColor = {0.7, 0.7, 0.7, 1}, -- Gray for arrows
        projectileSpeed = 200,
        projectileSize = 4
    },
    wizard = {
        name = "Wizard Goblin",
        description = "A mystical goblin with magical powers",
        cost = 10,
        health = 100,
        damage = 15,
        range = 2,
        color = {0.4, 0.3, 0.8, 1}, -- Purple
        size = 20,
        projectileColor = {0.2, 0.4, 0.9, 1}, -- Blue for magic
        projectileSpeed = 150,
        projectileSize = 6
    }
}

function GoblinUnit.new(unitType, position)
    local self = setmetatable({}, GoblinUnit)
    
    -- Set properties based on unit type
    local typeData = unitTypes[unitType] or unitTypes.warrior
    
    self.type = unitType
    self.name = typeData.name
    self.description = typeData.description
    self.cost = typeData.cost
    self.health = typeData.health
    self.damage = typeData.damage
    self.range = typeData.range
    self.color = typeData.color
    self.size = typeData.size
    self.projectileColor = typeData.projectileColor
    self.projectileSpeed = typeData.projectileSpeed
    self.projectileSize = typeData.projectileSize
    
    -- Position on game map (tile coordinates)
    self.position = position or {x = 0, y = 0}
    
    -- Targeting and attack info
    self.target = nil
    self.attackCooldown = 0
    self.attackSpeed = 1 -- Attacks per second
    
    -- Projectiles
    self.projectiles = {}
    
    return self
end

function GoblinUnit:update(dt, enemies)
    -- Update attack cooldown
    if self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end
    
    -- If no target or target is dead, find a new one
    if not self.target or self.target.isDead or self.target.reachedEnd then
        self:findTarget(enemies)
    end
    
    -- Attack target if in range and cooldown expired
    if self.target and self.attackCooldown <= 0 then
        self:attack()
    end
    
    -- Update projectiles
    for i = #self.projectiles, 1, -1 do
        local proj = self.projectiles[i]
        
        -- Update position
        local dx = proj.target.x - proj.position.x
        local dy = proj.target.y - proj.position.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        -- Normalize direction
        if distance > 0 then
            dx = dx / distance
            dy = dy / distance
        end
        
        -- Move projectile
        proj.position.x = proj.position.x + dx * self.projectileSpeed * dt
        proj.position.y = proj.position.y + dy * self.projectileSpeed * dt
        
        -- Check if projectile reached or passed target
        local newDistance = math.sqrt(
            (proj.target.x - proj.position.x)^2 + 
            (proj.target.y - proj.position.y)^2
        )
        
        if newDistance < 5 or distance < newDistance then
            table.remove(self.projectiles, i)
        end
    end
end

function GoblinUnit:findTarget(enemies)
    self.target = nil
    local closestDistance = math.huge
    
    for _, enemy in ipairs(enemies) do
        if not enemy.isDead and not enemy.reachedEnd then
            -- Calculate distance to enemy
            local dx = enemy.position.x - self.position.x
            local dy = enemy.position.y - self.position.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- If enemy is in range and closer than current target
            if distance <= self.range and distance < closestDistance then
                self.target = enemy
                closestDistance = distance
            end
        end
    end
end

function GoblinUnit:attack()
    if self.target then
        self.target:takeDamage(self.damage)
        self.attackCooldown = 1 / self.attackSpeed
        
        -- Create a new projectile
        local projectile = {
            position = {
                x = self.position.x,
                y = self.position.y
            },
            target = {
                x = self.target.position.x,
                y = self.target.position.y
            },
            size = self.projectileSize,
            color = self.projectileColor
        }
        
        table.insert(self.projectiles, projectile)
    end
end

function GoblinUnit:draw(offsetX, offsetY, tileSize)
    -- For a unit at position {x=2, y=3} we want to draw at tile (3,4)
    -- So we add 1 to the position to get the tile coordinates
    local tileX = self.position.x + 1
    local tileY = self.position.y + 1
    
    -- Convert to screen coordinates (center of the tile)
    local x = offsetX + (tileX - 1) * tileSize + tileSize / 2
    local y = offsetY + (tileY - 1) * tileSize + tileSize / 2
    
    -- Draw unit body
    love.graphics.setColor(unpack(self.color))
    love.graphics.circle("fill", x, y, self.size / 2)
    
    -- Draw unit features based on type
    if self.type == "warrior" then
        -- Draw shield
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.arc("fill", x - 2, y, self.size / 3, -math.pi/2, math.pi/2)
        
        -- Draw sword
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y - 10, 2, 20)
        
    elseif self.type == "archer" then
        -- Draw bow
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.arc("line", x + 8, y, self.size / 3, -math.pi/2, math.pi/2)
        
        -- Draw arrow
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.line(x, y, x + 15, y)
        
    elseif self.type == "wizard" then
        -- Draw wizard hat
        love.graphics.setColor(0.2, 0.2, 0.8, 1)
        love.graphics.polygon("fill", 
            x, y - self.size/2 - 10, 
            x - 10, y - self.size/2, 
            x + 10, y - self.size/2
        )
        
        -- Draw staff
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.line(x - 8, y - 5, x - 15, y + 10)
    end
    
    -- Draw projectiles
    for _, proj in ipairs(self.projectiles) do
        -- Convert projectile world position to screen position
        local projX = offsetX + proj.position.x * tileSize + tileSize / 2
        local projY = offsetY + proj.position.y * tileSize + tileSize / 2
        
        love.graphics.setColor(unpack(proj.color))
        
        -- Draw different projectile shapes based on unit type
        if self.type == "warrior" then
            -- Draw a slash effect
            love.graphics.arc("fill", projX, projY, proj.size, 0, math.pi * 1.5)
        elseif self.type == "archer" then
            -- Draw an arrow
            local targetX = offsetX + proj.target.x * tileSize + tileSize / 2
            local targetY = offsetY + proj.target.y * tileSize + tileSize / 2
            
            -- Calculate direction
            local dx = targetX - projX
            local dy = targetY - projY
            local angle = math.atan2(dy, dx)
            
            -- Draw arrow line
            love.graphics.setLineWidth(2)
            love.graphics.line(projX, projY, projX - math.cos(angle) * 8, projY - math.sin(angle) * 8)
            
            -- Draw arrowhead
            love.graphics.polygon("fill", 
                projX, projY,
                projX - math.cos(angle + 0.3) * 6, projY - math.sin(angle + 0.3) * 6,
                projX - math.cos(angle - 0.3) * 6, projY - math.sin(angle - 0.3) * 6
            )
            love.graphics.setLineWidth(1)
        elseif self.type == "wizard" then
            -- Draw a magic orb
            love.graphics.circle("fill", projX, projY, proj.size)
            
            -- Add a glow effect
            love.graphics.setColor(proj.color[1], proj.color[2], proj.color[3], 0.3)
            love.graphics.circle("fill", projX, projY, proj.size + 4)
        else
            -- Default projectile
            love.graphics.circle("fill", projX, projY, proj.size)
        end
    end
    
    -- Draw range indicator on hover (to be implemented in Game.lua)
end

-- Static method to get the unit types information
function GoblinUnit.getTypes()
    return unitTypes
end

return GoblinUnit 