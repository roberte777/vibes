local json = require("vendor.json.json")

-- Game Class
local Game = {}
Game.__index = Game

function Game.new(levelPath)
    local self = setmetatable({}, Game)
    
    -- Game state
    self.levelPath = levelPath
    self.map = {}
    self.tileSize = 40
    
    -- Load level data
    self:loadLevel()
    
    return self
end

function Game:loadLevel()
    if not self.levelPath then return end
    
    local contents = love.filesystem.read(self.levelPath)
    if contents then
        local levelData = json.decode(contents)
        if levelData and levelData.map then
            self.map = levelData.map
            self.levelName = levelData.name or "Unnamed Level"
        end
    end
end

function Game:update(dt)
    -- Game logic updates will go here
end

function Game:draw()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    
    -- Draw title
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.setColor(0.9, 0.7, 0.2, 1)  -- Gold color
    love.graphics.print(self.levelName or "Level", 20, 20)
    
    -- Draw map
    if self.map and #self.map > 0 then
        self:drawMap()
    end
    
    -- Draw start button
    self:drawStartButton(screenWidth, screenHeight)
end

function Game:drawMap()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    
    -- Calculate the map dimensions
    local mapRows = #self.map
    local mapCols = #self.map[1]
    
    -- Calculate the centering offset
    local offsetX = (screenWidth - (mapCols * self.tileSize)) / 2
    local offsetY = (screenHeight - (mapRows * self.tileSize)) / 2
    
    -- Draw the map tiles
    for r = 1, mapRows do
        for c = 1, mapCols do
            local char = self.map[r]:sub(c, c)
            
            if char == "1" then
                -- Grass tile
                love.graphics.setColor(0.2, 0.8, 0.2, 1)  -- Green
            else
                -- Path tile
                love.graphics.setColor(0.8, 0.6, 0.4, 1)  -- Brown
            end
            
            love.graphics.rectangle("fill", 
                offsetX + (c-1) * self.tileSize, 
                offsetY + (r-1) * self.tileSize, 
                self.tileSize, 
                self.tileSize)
            
            -- Draw grid lines
            love.graphics.setColor(0, 0, 0, 0.2)
            love.graphics.rectangle("line", 
                offsetX + (c-1) * self.tileSize, 
                offsetY + (r-1) * self.tileSize, 
                self.tileSize, 
                self.tileSize)
        end
    end
end

function Game:drawStartButton(screenWidth, screenHeight)
    -- Draw button in bottom right
    love.graphics.setColor(0.2, 0.7, 0.3, 1)  -- Green
    
    local buttonWidth = 120
    local buttonHeight = 50
    local buttonX = screenWidth - buttonWidth - 20  -- 20px from right edge
    local buttonY = screenHeight - buttonHeight - 20  -- 20px from bottom edge
    
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 10, 10)
    
    -- Draw button text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(18))
    local text = "Start"
    local textWidth = love.graphics.getFont():getWidth(text)
    love.graphics.print(text, buttonX + buttonWidth/2 - textWidth/2, buttonY + 15)
    
    -- Store button position for hit detection
    self.startButton = {
        x = buttonX,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight
    }
end

function Game:mousepressed(x, y, button)
    if button == 1 then  -- Left click
        -- Check if start button was clicked
        if self.startButton and
           x >= self.startButton.x and x <= self.startButton.x + self.startButton.width and
           y >= self.startButton.y and y <= self.startButton.y + self.startButton.height then
            -- Start the game
            return "start_game"
        end
        
        -- Add check for back button here if needed
    end
    
    return nil
end

return Game 