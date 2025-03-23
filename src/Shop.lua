-- Shop Class
local GoblinUnit = require("src.GoblinUnit")

local Shop = {}
Shop.__index = Shop

function Shop.new()
    local self = setmetatable({}, Shop)

    -- Shop state
    self.isOpen = false
    self.selectedUnit = nil
    self.hoveredUnit = nil
    self.unitTypes = GoblinUnit.getTypes()
    
    -- UI dimensions
    self.padding = 10
    self.unitCardWidth = 160
    self.unitCardHeight = 180
    self.shopHeight = 200
    
    return self
end

function Shop:open()
    self.isOpen = true
end

function Shop:close()
    self.isOpen = false
    self.selectedUnit = nil
    self.hoveredUnit = nil
end

function Shop:toggle()
    self.isOpen = not self.isOpen
    if not self.isOpen then
        self.selectedUnit = nil
        self.hoveredUnit = nil
    end
end

function Shop:update(dt)
    -- No units to update here, they're managed in Game
end

function Shop:draw(screenWidth, screenHeight, resources)
    if not self.isOpen then return end

    -- Draw shop background
    love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
    love.graphics.rectangle("fill", 0, screenHeight - self.shopHeight, screenWidth, self.shopHeight)
    
    -- Draw shop border
    love.graphics.setColor(0.3, 0.3, 0.4, 1)
    love.graphics.rectangle("line", 0, screenHeight - self.shopHeight, screenWidth, self.shopHeight)
    
    -- Draw shop title
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.setColor(0.9, 0.8, 0.3, 1) -- Gold color
    love.graphics.print("Goblin Shop", self.padding, screenHeight - self.shopHeight + self.padding)
    
    -- Draw unit cards
    local x = self.padding
    local y = screenHeight - self.shopHeight + 40
    local unitTypes = {"warrior", "archer", "wizard"}
    
    for _, unitType in ipairs(unitTypes) do
        local typeData = self.unitTypes[unitType]
        local cardColor = {0.2, 0.2, 0.25, 1}
        
        -- Change card background if selected or hovered
        if self.selectedUnit == unitType then
            cardColor = {0.3, 0.5, 0.3, 1}
        elseif self.hoveredUnit == unitType then
            cardColor = {0.25, 0.25, 0.3, 1}
        end
        
        -- Draw card background
        love.graphics.setColor(unpack(cardColor))
        love.graphics.rectangle("fill", x, y, self.unitCardWidth, self.unitCardHeight, 5, 5)
        
        -- Draw card border
        love.graphics.setColor(0.4, 0.4, 0.5, 1)
        love.graphics.rectangle("line", x, y, self.unitCardWidth, self.unitCardHeight, 5, 5)
        
        -- Draw unit icon (simplified representation)
        love.graphics.setColor(unpack(typeData.color))
        love.graphics.circle("fill", x + self.unitCardWidth/2, y + 50, 30)
        
        -- Draw unit-specific details
        if unitType == "warrior" then
            -- Draw shield
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.arc("fill", x + self.unitCardWidth/2 - 5, y + 50, 15, -math.pi/2, math.pi/2)
            
            -- Draw sword
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.rectangle("fill", x + self.unitCardWidth/2 + 10, y + 40, 3, 25)
            
        elseif unitType == "archer" then
            -- Draw bow
            love.graphics.setColor(0.6, 0.4, 0.2, 1)
            love.graphics.arc("line", x + self.unitCardWidth/2 + 15, y + 50, 12, -math.pi/2, math.pi/2)
            
            -- Draw arrow
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.line(x + self.unitCardWidth/2, y + 50, x + self.unitCardWidth/2 + 25, y + 50)
            
        elseif unitType == "wizard" then
            -- Draw wizard hat
            love.graphics.setColor(0.2, 0.2, 0.8, 1)
            love.graphics.polygon("fill", 
                x + self.unitCardWidth/2, y + 20, 
                x + self.unitCardWidth/2 - 15, y + 40, 
                x + self.unitCardWidth/2 + 15, y + 40
            )
            
            -- Draw staff
            love.graphics.setColor(0.6, 0.4, 0.2, 1)
            love.graphics.line(x + self.unitCardWidth/2 - 10, y + 45, x + self.unitCardWidth/2 - 20, y + 65)
        end
        
        -- Draw unit name
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        local nameWidth = love.graphics.getFont():getWidth(typeData.name)
        love.graphics.print(typeData.name, x + self.unitCardWidth/2 - nameWidth/2, y + 90)
        
        -- Draw cost
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(0.9, 0.8, 0.3, 1) -- Gold color
        local costText = typeData.cost .. " Gold"
        local costWidth = love.graphics.getFont():getWidth(costText)
        love.graphics.print(costText, x + self.unitCardWidth/2 - costWidth/2, y + 115)
        
        -- Draw "Sold Out" or "Unavailable" if not enough resources
        if resources < typeData.cost then
            love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
            love.graphics.rectangle("fill", x, y, self.unitCardWidth, self.unitCardHeight, 5, 5)
            
            love.graphics.setFont(love.graphics.newFont(14))
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            local unavailableText = "Can't Afford"
            local textWidth = love.graphics.getFont():getWidth(unavailableText)
            love.graphics.print(unavailableText, x + self.unitCardWidth/2 - textWidth/2, y + 140)
        end
        
        -- Move to next card position
        x = x + self.unitCardWidth + self.padding
    end
end

function Shop:mousepressed(x, y, button, resources)
    if not self.isOpen or button ~= 1 then return false end
    
    -- Check if click was inside shop area
    if y < love.graphics.getHeight() - self.shopHeight then return false end
    
    -- Check each unit card
    local cardX = self.padding
    local cardY = love.graphics.getHeight() - self.shopHeight + 40
    local unitTypes = {"warrior", "archer", "wizard"}
    
    for _, unitType in ipairs(unitTypes) do
        local typeData = self.unitTypes[unitType]
        
        -- Check if click was inside this card
        if x >= cardX and x <= cardX + self.unitCardWidth and
           y >= cardY and y <= cardY + self.unitCardHeight then
            
            -- Check if player has enough resources
            if resources >= typeData.cost then
                self.selectedUnit = unitType
                return true
            end
        end
        
        -- Move to next card position
        cardX = cardX + self.unitCardWidth + self.padding
    end
    
    return false
end

function Shop:mousemoved(x, y)
    if not self.isOpen then return end
    
    self.hoveredUnit = nil
    
    -- Check each unit card
    local cardX = self.padding
    local cardY = love.graphics.getHeight() - self.shopHeight + 40
    local unitTypes = {"warrior", "archer", "wizard"}
    
    for _, unitType in ipairs(unitTypes) do
        -- Check if mouse is inside this card
        if x >= cardX and x <= cardX + self.unitCardWidth and
           y >= cardY and y <= cardY + self.unitCardHeight then
            self.hoveredUnit = unitType
            return
        end
        
        -- Move to next card position
        cardX = cardX + self.unitCardWidth + self.padding
    end
end

function Shop:placeUnit(unitType, position)
    -- This function is no longer used
    return false
end

function Shop:getSelectedUnit()
    return self.selectedUnit
end

return Shop 