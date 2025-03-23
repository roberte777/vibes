local json = require("vendor.json.json")
local Enemy = require("src.Enemy")
local Shop = require("src.Shop")
local GoblinUnit = require("src.GoblinUnit")

-- Game Class
local Game = {}
Game.__index = Game

function Game.new(levelPath)
    local self = setmetatable({}, Game)

    -- Game state
    self.levelPath = levelPath
    self.map = {}
    self.tileSize = 40
    self.waypoints = {}
    self.enemies = {}
    self.waves = {}
    self.currentWave = 0
    self.gameStarted = false
    self.spawnTimer = 0
    self.lives = 20
    self.resources = 100
    self.mapOpen = false
    
    -- Shop and units
    self.shop = Shop.new()
    self.placingUnit = false
    self.units = {}

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
            self.waypoints = levelData.waypoints or {}
            self.waves = levelData.waves or {}
            self.lives = levelData.maxLives or 20
            self.resources = levelData.initialResources or 100
        end
    end
end

function Game:update(dt)
    if not self.gameStarted then return end

    -- Update existing enemies
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt)

        -- Check if enemy reached the end
        if enemy.reachedEnd then
            self.lives = self.lives - 1
            table.remove(self.enemies, i)
            -- Check if enemy died
        elseif enemy.isDead then
            self.resources = self.resources + 10 -- Reward for killing
            table.remove(self.enemies, i)
        end
    end
    
    -- Update units
    for _, unit in ipairs(self.units) do
        unit:update(dt, self.enemies)
    end
    
    -- No need to update shop's active units as we're managing units directly in Game
    if self.shop then
        self.shop:update(dt)
    end

    -- Check if we need to spawn enemies
    if self.currentWave > 0 and self.currentWave <= #self.waves then
        local wave = self.waves[self.currentWave]
        local enemyTypes = {}

        -- Collect all enemy types in this wave
        for _, enemyData in ipairs(wave.enemies) do
            if enemyData.count > 0 then
                table.insert(enemyTypes, enemyData)
            end
        end

        -- If there are enemy types to spawn
        if #enemyTypes > 0 then
            self.spawnTimer = self.spawnTimer + dt

            -- Find enemy type with shortest spawn interval
            local shortestInterval = math.huge
            local enemyToSpawn = nil

            for _, enemyData in ipairs(enemyTypes) do
                if enemyData.spawnInterval < shortestInterval and enemyData.count > 0 then
                    shortestInterval = enemyData.spawnInterval
                    enemyToSpawn = enemyData
                end
            end

            -- Spawn enemy if timer exceeded interval
            if self.spawnTimer >= shortestInterval and enemyToSpawn then
                -- Reset timer
                self.spawnTimer = 0

                -- Spawn enemy
                local enemy = Enemy.new(self.waypoints, enemyToSpawn.enemyType)
                table.insert(self.enemies, enemy)

                -- Decrease enemy count
                enemyToSpawn.count = enemyToSpawn.count - 1
            end
        else
            -- All enemies in wave have been spawned
            if #self.enemies == 0 then
                -- Move to next wave
                self.currentWave = self.currentWave + 1
                self.spawnTimer = 0
            end
        end
    end

    -- Check game over condition
    if self.lives <= 0 then
        self.gameStarted = false
        print("Game Over - You lost!")
    end

    -- Check win condition
    if self.currentWave > #self.waves and #self.enemies == 0 then
        self.gameStarted = false
        print("Victory!")
    end
end

function Game:draw()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    -- Draw title
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.setColor(0.9, 0.7, 0.2, 1) -- Gold color
    love.graphics.print(self.levelName or "Level", 20, 20)

    -- Draw map
    if self.map and #self.map > 0 then
        self:drawMap()
    end

    -- Draw path waypoints if game not started
    if not self.gameStarted and self.waypoints and #self.waypoints > 0 then
        self:drawWaypoints()
    end

    -- Calculate map dimensions and offsets for enemy positioning
    local mapRows = #self.map
    local mapCols = #self.map[1]
    local offsetX = (screenWidth - (mapCols * self.tileSize)) / 2
    local offsetY = (screenHeight - (mapRows * self.tileSize)) / 2

    -- Draw enemies
    for _, enemy in ipairs(self.enemies) do
        enemy:draw(offsetX, offsetY, self.tileSize)
    end
    
    -- Draw units
    for _, unit in ipairs(self.units) do
        unit:draw(offsetX, offsetY, self.tileSize)
    end
    
    -- Draw unit placement indicator if placing a unit
    if self.placingUnit and self.hoverTile then
        local unitType = self.shop:getSelectedUnit()
        if unitType then
            local typeData = GoblinUnit.getTypes()[unitType]
            
            -- Calculate proper position for preview
            local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
            local mapRows = #self.map
            local mapCols = #self.map[1]
            local offsetX = (screenWidth - (mapCols * self.tileSize)) / 2
            local offsetY = (screenHeight - (mapRows * self.tileSize)) / 2
            
            -- Match exactly the same calculation as in GoblinUnit:draw
            local tileX = self.hoverTile.x
            local tileY = self.hoverTile.y
            
            -- Convert to screen coordinates (center of the tile)
            local previewX = offsetX + (tileX - 1) * self.tileSize + self.tileSize / 2
            local previewY = offsetY + (tileY - 1) * self.tileSize + self.tileSize / 2
            
            -- Draw semi-transparent unit at hover position
            love.graphics.setColor(typeData.color[1], typeData.color[2], typeData.color[3], 0.5)
            love.graphics.circle("fill", previewX, previewY, typeData.size / 2)
            
            -- Draw range indicator
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.circle("line", previewX, previewY, typeData.range * self.tileSize)
        end
    end

    -- Draw UI elements
    self:drawUI(screenWidth, screenHeight)

    -- Draw start button if game not started
    if not self.gameStarted then
        self:drawStartButton(screenWidth, screenHeight)
    end
    
    -- Draw map toggle button
    self:drawMapButton(screenWidth, screenHeight)
    
    -- Draw shop if map is open
    if self.mapOpen and self.shop then
        self.shop:draw(screenWidth, screenHeight, self.resources)
    end
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
                love.graphics.setColor(0.2, 0.8, 0.2, 1) -- Green
            else
                -- Path tile
                love.graphics.setColor(0.8, 0.6, 0.4, 1) -- Brown
            end

            love.graphics.rectangle("fill",
                offsetX + (c - 1) * self.tileSize,
                offsetY + (r - 1) * self.tileSize,
                self.tileSize,
                self.tileSize)

            -- Draw grid lines
            love.graphics.setColor(0, 0, 0, 0.2)
            love.graphics.rectangle("line",
                offsetX + (c - 1) * self.tileSize,
                offsetY + (r - 1) * self.tileSize,
                self.tileSize,
                self.tileSize)
        end
    end
end

function Game:drawWaypoints()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    -- Calculate the map dimensions
    local mapRows = #self.map
    local mapCols = #self.map[1]

    -- Calculate the centering offset
    local offsetX = (screenWidth - (mapCols * self.tileSize)) / 2
    local offsetY = (screenHeight - (mapRows * self.tileSize)) / 2

    -- Draw waypoints and connect them with lines
    if #self.waypoints > 0 then
        -- Draw lines connecting waypoints
        love.graphics.setColor(1, 0, 0, 0.7) -- Red with transparency
        love.graphics.setLineWidth(3)

        for i = 1, #self.waypoints - 1 do
            local current = self.waypoints[i]
            local next = self.waypoints[i + 1]

            love.graphics.line(
                offsetX + current.x * self.tileSize + self.tileSize / 2,
                offsetY + current.y * self.tileSize + self.tileSize / 2,
                offsetX + next.x * self.tileSize + self.tileSize / 2,
                offsetY + next.y * self.tileSize + self.tileSize / 2
            )
        end

        -- Draw waypoint markers
        for i, point in ipairs(self.waypoints) do
            local x = offsetX + point.x * self.tileSize + self.tileSize / 2
            local y = offsetY + point.y * self.tileSize + self.tileSize / 2

            if i == 1 then
                -- Start waypoint
                love.graphics.setColor(0, 1, 0, 1) -- Green for start
                love.graphics.circle("fill", x, y, 8)

                -- Draw small label
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.setFont(love.graphics.newFont(12))
                love.graphics.print("START", x - 18, y - 25)
            elseif i == #self.waypoints then
                -- End waypoint
                love.graphics.setColor(1, 0, 0, 1) -- Red for end
                love.graphics.circle("fill", x, y, 8)

                -- Draw small label
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.setFont(love.graphics.newFont(12))
                love.graphics.print("END", x - 12, y - 25)
            else
                -- Middle waypoint
                love.graphics.setColor(1, 1, 0, 1) -- Yellow for middle points
                love.graphics.circle("fill", x, y, 5)
            end

            -- Draw waypoint number
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setFont(love.graphics.newFont(12))
            local numWidth = love.graphics.getFont():getWidth(tostring(i))
            love.graphics.print(tostring(i), x - numWidth / 2, y - 6)
        end
    end
end

function Game:drawUI(screenWidth, screenHeight)
    -- UI background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", 10, 60, 200, 80, 5, 5)

    -- Lives
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(1, 0.5, 0.5, 1)
    love.graphics.print("Lives: " .. self.lives, 20, 70)

    -- Resources
    love.graphics.setColor(0.5, 0.9, 0.5, 1)
    love.graphics.print("Gold: " .. self.resources, 20, 100)

    -- Wave info
    love.graphics.setColor(0.5, 0.7, 1, 1)
    if self.gameStarted then
        love.graphics.print("Wave: " .. self.currentWave .. "/" .. #self.waves, 20, 130)
    else
        love.graphics.print("Wave: -/" .. #self.waves, 20, 130)
    end
end

function Game:drawStartButton(screenWidth, screenHeight)
    -- Draw button in bottom right
    love.graphics.setColor(0.2, 0.7, 0.3, 1) -- Green

    local buttonWidth = 120
    local buttonHeight = 50
    local buttonX = screenWidth - buttonWidth - 20   -- 20px from right edge
    local buttonY = screenHeight - buttonHeight - 20 -- 20px from bottom edge

    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 10, 10)

    -- Draw button text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(18))
    local text = "Start"
    local textWidth = love.graphics.getFont():getWidth(text)
    love.graphics.print(text, buttonX + buttonWidth / 2 - textWidth / 2, buttonY + 15)

    -- Store button position for hit detection
    self.startButton = {
        x = buttonX,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight
    }
end

function Game:drawMapButton(screenWidth, screenHeight)
    -- Draw map toggle button in top right
    local buttonWidth = 120
    local buttonHeight = 40
    local buttonX = screenWidth - buttonWidth - 20   -- 20px from right edge
    local buttonY = 20                               -- 20px from top edge
    
    -- Change color based on state
    if self.mapOpen then
        love.graphics.setColor(0.7, 0.2, 0.3, 1) -- Red when open
    else
        love.graphics.setColor(0.2, 0.3, 0.7, 1) -- Blue when closed
    end

    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 10, 10)

    -- Draw button text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16))
    local text = self.mapOpen and "Close Shop" or "Open Shop"
    local textWidth = love.graphics.getFont():getWidth(text)
    love.graphics.print(text, buttonX + buttonWidth / 2 - textWidth / 2, buttonY + 10)

    -- Store button position for hit detection
    self.mapButton = {
        x = buttonX,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight
    }
end

function Game:mousepressed(x, y, button)
    if button == 1 then -- Left click
        -- Check if map button was clicked
        if self.mapButton and
            x >= self.mapButton.x and x <= self.mapButton.x + self.mapButton.width and
            y >= self.mapButton.y and y <= self.mapButton.y + self.mapButton.height then
            -- Toggle map/shop
            self.mapOpen = not self.mapOpen
            
            if self.mapOpen then
                self.shop:open()
            else
                self.shop:close()
                self.placingUnit = false
            end
            
            return "map_toggled"
        end
    
        -- Check if start button was clicked
        if not self.gameStarted and self.startButton and
            x >= self.startButton.x and x <= self.startButton.x + self.startButton.width and
            y >= self.startButton.y and y <= self.startButton.y + self.startButton.height then
            -- Start the game
            self.gameStarted = true
            self.currentWave = 1
            self.spawnTimer = 0
            return "game_started"
        end
        
        -- Check if shop was clicked
        if self.mapOpen and self.shop:mousepressed(x, y, button, self.resources) then
            self.placingUnit = true
            return "unit_selected"
        end
        
        -- If placing a unit and clicked on the map
        if self.placingUnit and self.hoverTile then
            local unitType = self.shop:getSelectedUnit()
            if unitType then
                -- Check if tile is valid for placement (not on path)
                local mapX = self.hoverTile.x
                local mapY = self.hoverTile.y
                
                -- Check if tile is within map bounds
                if mapY >= 1 and mapY <= #self.map and
                   mapX >= 1 and mapX <= #self.map[1] then
                    
                    -- Check if the tile is a grass tile (1)
                    local tileChar = self.map[mapY]:sub(mapX, mapX)
                    if tileChar == "1" then
                        -- Check if there's already a unit on this tile
                        local tileOccupied = false
                        for _, unit in ipairs(self.units) do
                            -- Use the same coordinate system for comparison as when we place units
                            if unit.position.x == mapX - 1 and unit.position.y == mapY - 1 then
                                tileOccupied = true
                                break
                            end
                        end
                        
                        if not tileOccupied then
                            -- Create a new unit using coordinates that match how we draw them
                            -- The position.x and position.y in GoblinUnit should match the tile coordinates
                            local newUnit = GoblinUnit.new(unitType, {x = mapX - 1, y = mapY - 1})
                            table.insert(self.units, newUnit)
                            
                            -- Deduct cost
                            self.resources = self.resources - newUnit.cost
                            
                            -- Reset placement state
                            self.placingUnit = false
                            self.shop.selectedUnit = nil
                            
                            return "unit_placed"
                        end
                    end
                end
            end
        end
    end

    return nil
end

function Game:mousemoved(x, y)
    -- Update shop hover state
    if self.mapOpen then
        self.shop:mousemoved(x, y)
    end
    
    -- Update hover tile for unit placement
    if self.placingUnit then
        local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
        local mapRows = #self.map
        local mapCols = #self.map[1]
        local offsetX = (screenWidth - (mapCols * self.tileSize)) / 2
        local offsetY = (screenHeight - (mapRows * self.tileSize)) / 2
        
        -- Calculate map tile coordinates from mouse position
        local tileX = math.floor((x - offsetX) / self.tileSize) + 1
        local tileY = math.floor((y - offsetY) / self.tileSize) + 1
        
        -- Store hover tile if within map bounds
        if tileX >= 1 and tileX <= mapCols and
           tileY >= 1 and tileY <= mapRows then
            self.hoverTile = {x = tileX, y = tileY}
        else
            self.hoverTile = nil
        end
    end
end

return Game
