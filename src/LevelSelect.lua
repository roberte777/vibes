local json = require("vendor.json.json")

-- LevelSelect Class
local LevelSelect = {}
LevelSelect.__index = LevelSelect

function LevelSelect.new()
    local self = setmetatable({}, LevelSelect)
    
    -- Level selection state
    self.levels = {}
    self.currentPage = 1
    self.levelsPerPage = 9  -- 3x3 grid
    self.selectedLevel = nil
    
    -- UI elements
    self.gridSize = 3
    self.previewSize = 100
    self.spacing = 20
    
    -- Load all levels
    self:loadLevels()
    
    return self
end

function LevelSelect:loadLevels()
    self.levels = {}
    local files = love.filesystem.getDirectoryItems("levels")
    
    for _, file in ipairs(files) do
        if file:match("%.json$") then
            local path = "levels/" .. file
            local contents = love.filesystem.read(path)
            if contents then
                local levelData = json.decode(contents)
                if levelData then
                    table.insert(self.levels, {
                        name = levelData.name or "Unnamed Level",
                        path = path,
                        data = levelData
                    })
                end
            end
        end
    end
end

function LevelSelect:update(dt)
    -- Handle any animations or updates here
end

function LevelSelect:draw()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    
    -- Draw title
    love.graphics.setFont(love.graphics.newFont(48))
    love.graphics.setColor(0.9, 0.7, 0.2, 1)  -- Gold color similar to menu
    local title = "Goblin Blasters"
    local titleWidth = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, screenWidth / 2 - titleWidth / 2, 30)
    
    -- Draw level grid
    local startIdx = (self.currentPage - 1) * self.levelsPerPage + 1
    local endIdx = math.min(startIdx + self.levelsPerPage - 1, #self.levels)
    
    local gridStartX = (screenWidth - (self.gridSize * (self.previewSize + self.spacing))) / 2 + self.spacing / 2
    local gridStartY = 120
    
    for i = startIdx, endIdx do
        local level = self.levels[i]
        local idx = i - startIdx
        local row = math.floor(idx / self.gridSize)
        local col = idx % self.gridSize
        
        local x = gridStartX + col * (self.previewSize + self.spacing)
        local y = gridStartY + row * (self.previewSize + self.spacing + 30)  -- Extra 30px for level name
        
        -- Draw level preview background
        love.graphics.setColor(0.2, 0.2, 0.3, 1)
        love.graphics.rectangle("fill", x, y, self.previewSize, self.previewSize)
        
        -- Draw map preview if available
        if level.data.map then
            self:drawMapPreview(level.data.map, x, y, self.previewSize)
        end
        
        -- Draw level name
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(1, 1, 1, 1)
        local nameWidth = love.graphics.getFont():getWidth(level.name)
        love.graphics.print(level.name, x + self.previewSize/2 - nameWidth/2, y + self.previewSize + 5)
    end
    
    -- Draw navigation arrows if needed
    if #self.levels > self.levelsPerPage then
        love.graphics.setFont(love.graphics.newFont(36))
        
        -- Left arrow
        if self.currentPage > 1 then
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print("<", gridStartX - 50, screenHeight / 2 - 18)
        end
        
        -- Right arrow
        if self.currentPage < math.ceil(#self.levels / self.levelsPerPage) then
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print(">", gridStartX + self.gridSize * (self.previewSize + self.spacing) + 20, screenHeight / 2 - 18)
        end
    end
    
    -- Draw back button
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.setColor(0.7, 0.3, 0.3, 1)
    love.graphics.print("Back to Menu", 20, screenHeight - 40)
end

function LevelSelect:drawMapPreview(map, x, y, size)
    if not map or #map == 0 then
        return
    end
    
    -- Calculate tile size
    local rows = #map
    local cols = #map[1]
    local tileWidth = size / cols
    local tileHeight = size / rows
    
    for r = 1, rows do
        for c = 1, cols do
            local char = map[r]:sub(c, c)
            if char == "1" then
                -- Grass tile
                love.graphics.setColor(0.2, 0.8, 0.2, 1)  -- Green
            else
                -- Path tile
                love.graphics.setColor(0.8, 0.6, 0.4, 1)  -- Brown
            end
            
            love.graphics.rectangle("fill", 
                x + (c-1) * tileWidth, 
                y + (r-1) * tileHeight, 
                tileWidth, 
                tileHeight)
        end
    end
end

function LevelSelect:mousepressed(x, y, button)
    if button == 1 then  -- Left click
        local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
        
        -- Check if back button was clicked
        if x >= 20 and x <= 150 and y >= screenHeight - 40 and y <= screenHeight - 10 then
            return "menu"  -- Return to menu
        end
        
        -- Check level selection
        local gridStartX = (screenWidth - (self.gridSize * (self.previewSize + self.spacing))) / 2 + self.spacing / 2
        local gridStartY = 120
        
        local startIdx = (self.currentPage - 1) * self.levelsPerPage + 1
        local endIdx = math.min(startIdx + self.levelsPerPage - 1, #self.levels)
        
        for i = startIdx, endIdx do
            local idx = i - startIdx
            local row = math.floor(idx / self.gridSize)
            local col = idx % self.gridSize
            
            local levelX = gridStartX + col * (self.previewSize + self.spacing)
            local levelY = gridStartY + row * (self.previewSize + self.spacing + 30)
            
            if x >= levelX and x <= levelX + self.previewSize and
               y >= levelY and y <= levelY + self.previewSize then
                -- Level selected
                self.selectedLevel = self.levels[i].path
                return "play_level", self.selectedLevel
            end
        end
        
        -- Check navigation arrows
        if #self.levels > self.levelsPerPage then
            -- Left arrow
            if self.currentPage > 1 and 
               x >= gridStartX - 50 and x <= gridStartX - 10 and
               y >= screenHeight / 2 - 18 and y <= screenHeight / 2 + 18 then
                self.currentPage = self.currentPage - 1
            end
            
            -- Right arrow
            local rightArrowX = gridStartX + self.gridSize * (self.previewSize + self.spacing) + 20
            if self.currentPage < math.ceil(#self.levels / self.levelsPerPage) and
               x >= rightArrowX and x <= rightArrowX + 40 and
               y >= screenHeight / 2 - 18 and y <= screenHeight / 2 + 18 then
                self.currentPage = self.currentPage + 1
            end
        end
    end
    
    return nil
end

return LevelSelect 