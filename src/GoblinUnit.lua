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
        range = 2,
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
        range = 4,
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
        range = 3,
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
    
    -- Animation state
    self.isAttacking = false
    self.attackAnimTimer = 0
    
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
        self.isAttacking = true
        self.attackAnimTimer = 0.3 -- Attack animation lasts 0.3 seconds
    end
    
    -- Update attack animation
    if self.isAttacking then
        self.attackAnimTimer = self.attackAnimTimer - dt
        if self.attackAnimTimer <= 0 then
            self.isAttacking = false
        end
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
        
        -- Update animation timer
        proj.animTimer = (proj.animTimer or 0) + dt
        
        -- Update projectile trails
        if proj.trails then
            -- Add new trail particle every few frames
            proj.trailTimer = (proj.trailTimer or 0) + dt
            if proj.trailTimer > 0.05 then
                table.insert(proj.trails, {
                    x = proj.position.x,
                    y = proj.position.y,
                    size = proj.size * 0.8,
                    alpha = 0.7,
                    age = 0
                })
                proj.trailTimer = 0
            end
            
            -- Update existing trail particles
            for j = #proj.trails, 1, -1 do
                local trail = proj.trails[j]
                trail.age = trail.age + dt
                trail.alpha = trail.alpha - dt * 1.5
                trail.size = trail.size - dt * 4
                
                if trail.alpha <= 0 or trail.size <= 0 then
                    table.remove(proj.trails, j)
                end
            end
        end
        
        -- Check if projectile reached or passed target
        local newDistance = math.sqrt(
            (proj.target.x - proj.position.x)^2 + 
            (proj.target.y - proj.position.y)^2
        )
        
        if newDistance < 5 or distance < newDistance then
            -- Create impact effect if this projectile has impactEffect set
            if proj.impactEffect then
                -- Add impact to different table
                -- (would be implemented in Game.lua)
            end
            
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
            color = self.projectileColor,
            animTimer = 0,
            rotationSpeed = math.random() * 8 - 4, -- Random rotation speed
            trails = {},
            trailTimer = 0
        }
        
        -- Add type-specific properties
        if self.type == "warrior" then
            projectile.slashAngle = 0
            projectile.slashGrowth = 1.5
        elseif self.type == "wizard" then
            projectile.pulseSpeed = 3 + math.random() * 2
            projectile.impactEffect = "magic"
        elseif self.type == "archer" then
            projectile.impactEffect = "pierce"
        end
        
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
    
    -- Draw unit features based on type with attack animation
    if self.type == "warrior" then
        -- Draw shield
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.arc("fill", x - 2, y, self.size / 3, -math.pi/2, math.pi/2)
        
        -- Draw sword with attack animation
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        
        if self.isAttacking then
            -- Sword swing animation
            local swingAngle = (0.3 - self.attackAnimTimer) / 0.3 * math.pi -- Swing 180 degrees
            local swordX = x + math.cos(swingAngle) * 10
            local swordY = y - 5 + math.sin(swingAngle) * 10
            
            love.graphics.push()
            love.graphics.translate(swordX, swordY)
            love.graphics.rotate(swingAngle + math.pi/4)
            love.graphics.rectangle("fill", 0, -10, 2, 20)
            love.graphics.pop()
        else
            -- Regular sword
            love.graphics.rectangle("fill", x + 5, y - 10, 2, 20)
        end
        
    elseif self.type == "archer" then
        -- Draw bow with attack animation
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        
        local bowStretch = 0
        if self.isAttacking then
            -- Bow drawing animation
            bowStretch = math.sin((0.3 - self.attackAnimTimer) / 0.3 * math.pi) * 5
        end
        
        -- Draw bow
        love.graphics.arc("line", x + 8, y, self.size / 3 + bowStretch, -math.pi/2, math.pi/2)
        
        -- Draw bowstring
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.line(
            x + 8, y - self.size / 3 - bowStretch,
            x + 8 - bowStretch, y,
            x + 8, y + self.size / 3 + bowStretch
        )
        
        -- Draw arrow
        if not self.isAttacking then
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.line(x, y, x + 15, y)
        end
        
    elseif self.type == "wizard" then
        -- Draw wizard hat
        love.graphics.setColor(0.2, 0.2, 0.8, 1)
        love.graphics.polygon("fill", 
            x, y - self.size/2 - 10, 
            x - 10, y - self.size/2, 
            x + 10, y - self.size/2
        )
        
        -- Draw staff with magical effects
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.line(x - 8, y - 5, x - 15, y + 10)
        
        -- Add magical glow if attacking
        if self.isAttacking then
            -- Pulsing staff tip
            local pulseSize = math.sin(love.timer.getTime() * 10) * 3 + 4
            love.graphics.setColor(0.2, 0.4, 0.9, 0.7)
            love.graphics.circle("fill", x - 15, y + 10, pulseSize)
            
            -- Magic sparkles
            for i = 1, 5 do
                local angle = love.timer.getTime() * 4 + i * math.pi * 2 / 5
                local sparkX = x - 15 + math.cos(angle) * 8
                local sparkY = y + 10 + math.sin(angle) * 8
                love.graphics.setColor(0.7, 0.7, 1.0, 0.5)
                love.graphics.circle("fill", sparkX, sparkY, 2)
            end
        end
    end
    
    -- Draw projectile trails first (behind projectiles)
    for _, proj in ipairs(self.projectiles) do
        if proj.trails then
            for _, trail in ipairs(proj.trails) do
                -- Convert trail world position to screen position
                local trailX = offsetX + trail.x * tileSize + tileSize / 2
                local trailY = offsetY + trail.y * tileSize + tileSize / 2
                
                -- Draw trail with fading alpha
                love.graphics.setColor(
                    self.projectileColor[1], 
                    self.projectileColor[2], 
                    self.projectileColor[3], 
                    trail.alpha
                )
                
                if self.type == "warrior" then
                    -- Slash trail
                    love.graphics.arc("fill", trailX, trailY, trail.size, 0, math.pi * 1.2)
                elseif self.type == "archer" then
                    -- Arrow trail
                    love.graphics.circle("fill", trailX, trailY, trail.size / 2)
                elseif self.type == "wizard" then
                    -- Magic trail with glow
                    love.graphics.circle("fill", trailX, trailY, trail.size)
                    love.graphics.setColor(
                        self.projectileColor[1], 
                        self.projectileColor[2], 
                        self.projectileColor[3], 
                        trail.alpha * 0.4
                    )
                    love.graphics.circle("fill", trailX, trailY, trail.size * 1.5)
                end
            end
        end
    end
    
    -- Draw projectiles
    for _, proj in ipairs(self.projectiles) do
        -- Convert projectile world position to screen position
        local projX = offsetX + proj.position.x * tileSize + tileSize / 2
        local projY = offsetY + proj.position.y * tileSize + tileSize / 2
        
        love.graphics.setColor(unpack(proj.color))
        
        -- Draw different projectile shapes based on unit type
        if self.type == "warrior" then
            -- Draw a dynamic slash effect
            local slashSize = proj.size * (1 + proj.animTimer * proj.slashGrowth)
            local slashAngle = proj.animTimer * 6
            
            love.graphics.push()
            love.graphics.translate(projX, projY)
            love.graphics.rotate(slashAngle)
            love.graphics.arc("fill", 0, 0, slashSize, 0, math.pi * 1.5)
            
            -- Add some motion lines
            love.graphics.setColor(1, 1, 1, 0.7)
            for i = 1, 3 do
                local lineAngle = slashAngle + i * math.pi / 6
                local lineLength = slashSize * 0.8
                love.graphics.line(
                    0, 0,
                    math.cos(lineAngle) * lineLength,
                    math.sin(lineAngle) * lineLength
                )
            end
            love.graphics.pop()
            
        elseif self.type == "archer" then
            -- Draw a spinning arrow
            local targetX = offsetX + proj.target.x * tileSize + tileSize / 2
            local targetY = offsetY + proj.target.y * tileSize + tileSize / 2
            
            -- Calculate direction
            local dx = targetX - projX
            local dy = targetY - projY
            local angle = math.atan2(dy, dx)
            
            -- Draw arrow with slight wobble
            love.graphics.push()
            love.graphics.translate(projX, projY)
            love.graphics.rotate(angle + math.sin(proj.animTimer * 8) * 0.1)
            
            -- Draw arrow shaft
            love.graphics.setLineWidth(2)
            love.graphics.line(0, 0, -12, 0)
            
            -- Draw fletching
            love.graphics.setColor(0.9, 0.3, 0.2, 1) -- Red fletching
            love.graphics.polygon("fill", 
                -10, 0,
                -15, 3,
                -14, 0,
                -15, -3
            )
            
            -- Draw arrowhead
            love.graphics.setColor(unpack(proj.color))
            love.graphics.polygon("fill", 
                0, 0,
                -5, 3,
                -5, -3
            )
            
            love.graphics.setLineWidth(1)
            love.graphics.pop()
            
        elseif self.type == "wizard" then
            -- Draw a pulsating magic orb
            local pulseSize = math.sin(proj.animTimer * proj.pulseSpeed) * 2
            
            -- Inner orb
            love.graphics.circle("fill", projX, projY, proj.size + pulseSize)
            
            -- Outer glow
            love.graphics.setColor(
                proj.color[1], 
                proj.color[2], 
                proj.color[3], 
                0.3 + math.sin(proj.animTimer * proj.pulseSpeed * 2) * 0.1
            )
            love.graphics.circle("fill", projX, projY, proj.size * 1.5 + pulseSize)
            
            -- Magical runes/symbols rotating around the orb
            love.graphics.setColor(1, 1, 1, 0.8)
            for i = 1, 4 do
                local runeAngle = proj.animTimer * 3 + i * math.pi / 2
                local runeX = projX + math.cos(runeAngle) * (proj.size + 5)
                local runeY = projY + math.sin(runeAngle) * (proj.size + 5)
                
                love.graphics.circle("fill", runeX, runeY, 2)
            end
        else
            -- Default projectile with rotation
            love.graphics.push()
            love.graphics.translate(projX, projY)
            love.graphics.rotate(proj.animTimer * proj.rotationSpeed)
            love.graphics.circle("fill", 0, 0, proj.size)
            love.graphics.pop()
        end
    end
    
    -- Draw range indicator on hover (to be implemented in Game.lua)
end

-- Static method to get the unit types information
function GoblinUnit.getTypes()
    return unitTypes
end

return GoblinUnit 