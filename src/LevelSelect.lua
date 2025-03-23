local json = require("vendor.json.json")

-- LevelSelect Class
local LevelSelect = {}
LevelSelect.__index = LevelSelect

function LevelSelect.new()
    local self = setmetatable({}, LevelSelect)

    -- Level selection state
    self.levels = {}
    self.currentPage = 1
    self.levelsPerPage = 9 -- 3x3 grid
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

    -- Ensure both directories exist
    love.filesystem.createDirectory("levels/default")
    love.filesystem.createDirectory("levels/custom")

    -- Load default levels
    local function loadLevelsFromDir(directory)
        local files = love.filesystem.getDirectoryItems(directory)
        for _, file in ipairs(files) do
            if file:match("%.json$") then
                local path = directory .. "/" .. file
                local contents = love.filesystem.read(path)
                if contents then
                    local levelData = json.decode(contents)
                    if levelData then
                        table.insert(self.levels, {
                            name = levelData.name or "Unnamed Level",
                            path = path,
                            data = levelData,
                            isDefault = directory == "levels/default"
                        })
                    end
                end
            end
        end
    end

    -- Load from both directories
    loadLevelsFromDir("levels/default")
    loadLevelsFromDir("levels/custom")
end

function LevelSelect:update(dt)
    -- Handle any animations or updates here
end

function LevelSelect:draw()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    -- Draw title
    love.graphics.setFont(love.graphics.newFont(48))
    love.graphics.setColor(0.9, 0.7, 0.2, 1) -- Gold color similar to menu
    local title = "Goblin Blasters"
    local titleWidth = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, screenWidth / 2 - titleWidth / 2, 30)

    -- Draw "Create New Level" button
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.setColor(0.3, 0.8, 0.3, 1) -- Green
    love.graphics.rectangle("fill", screenWidth - 220, 80, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    local newLevelText = "Create New Level"
    local newLevelWidth = love.graphics.getFont():getWidth(newLevelText)
    love.graphics.print(newLevelText, screenWidth - 220 + (200 - newLevelWidth) / 2, 90)

    -- Store button position for hit detection
    self.createNewLevelButton = {
        x = screenWidth - 220,
        y = 80,
        width = 200,
        height = 40
    }

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
        local y = gridStartY + row * (self.previewSize + self.spacing + 30) -- Extra 30px for level name

        -- Draw level preview background
        love.graphics.setColor(0.2, 0.2, 0.3, 1)
        love.graphics.rectangle("fill", x, y, self.previewSize, self.previewSize)

        -- Draw map preview if available
        if level.data.map then
            self:drawMapPreview(level.data.map, x, y, self.previewSize)
        end

        -- Draw waypoints preview if available
        if level.data.waypoints and #level.data.waypoints > 0 then
            self:drawWaypointsPreview(level.data.waypoints, x, y, self.previewSize, #level.data.map, #level.data.map[1])
        end

        -- Draw default level indicator if applicable
        if level.isDefault then
            love.graphics.setColor(0.9, 0.7, 0.2, 1) -- Gold color
            love.graphics.rectangle("line", x - 2, y - 2, self.previewSize + 4, self.previewSize + 4, 3, 3)

            -- Add a small "DEFAULT" label
            love.graphics.setFont(love.graphics.newFont(10))
            love.graphics.setColor(0.9, 0.7, 0.2, 1)
            love.graphics.print("DEFAULT", x + 5, y + 5)
        end

        -- Draw level name
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(1, 1, 1, 1)
        local nameWidth = love.graphics.getFont():getWidth(level.name)
        love.graphics.print(level.name, x + self.previewSize / 2 - nameWidth / 2, y + self.previewSize + 5)

        -- Draw edit button
        love.graphics.setColor(0.3, 0.6, 0.9, 1)
        love.graphics.rectangle("fill", x + self.previewSize - 30, y + 5, 25, 25, 3, 3)

        -- Draw edit icon
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + self.previewSize - 25, y + 15, x + self.previewSize - 10, y + 15)
        love.graphics.line(x + self.previewSize - 25, y + 20, x + self.previewSize - 10, y + 20)
        love.graphics.line(x + self.previewSize - 20, y + 10, x + self.previewSize - 20, y + 25)

        -- Store edit button position for hit detection
        level.editButton = {
            x = x + self.previewSize - 30,
            y = y + 5,
            width = 25,
            height = 25
        }
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
            love.graphics.print(">", gridStartX + self.gridSize * (self.previewSize + self.spacing) + 20,
                screenHeight / 2 - 18)
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
                love.graphics.setColor(0.2, 0.8, 0.2, 1) -- Green
            else
                -- Path tile
                love.graphics.setColor(0.8, 0.6, 0.4, 1) -- Brown
            end

            love.graphics.rectangle("fill",
                x + (c - 1) * tileWidth,
                y + (r - 1) * tileHeight,
                tileWidth,
                tileHeight)
        end
    end
end

function LevelSelect:drawWaypointsPreview(waypoints, x, y, size, rows, cols)
    if not waypoints or #waypoints < 2 then
        return
    end

    -- Calculate scale factors
    local tileWidth = size / cols
    local tileHeight = size / rows

    -- Draw waypoint path
    love.graphics.setColor(1, 0, 0, 0.7) -- Red with transparency
    love.graphics.setLineWidth(2)

    for i = 1, #waypoints - 1 do
        local current = waypoints[i]
        local next = waypoints[i + 1]

        love.graphics.line(
            x + current.x * tileWidth + tileWidth / 2,
            y + current.y * tileHeight + tileHeight / 2,
            x + next.x * tileWidth + tileWidth / 2,
            y + next.y * tileHeight + tileHeight / 2
        )
    end

    -- Draw start and end points
    if #waypoints > 0 then
        -- Start point (green)
        local start = waypoints[1]
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.circle("fill",
            x + start.x * tileWidth + tileWidth / 2,
            y + start.y * tileHeight + tileHeight / 2,
            3)

        -- End point (red)
        local endPoint = waypoints[#waypoints]
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.circle("fill",
            x + endPoint.x * tileWidth + tileWidth / 2,
            y + endPoint.y * tileHeight + tileHeight / 2,
            3)
    end
end

function LevelSelect:mousepressed(x, y, button)
    if button == 1 then -- Left click
        local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

        -- Check if "Create New Level" button was clicked
        if self.createNewLevelButton and
            x >= self.createNewLevelButton.x and x <= self.createNewLevelButton.x + self.createNewLevelButton.width and
            y >= self.createNewLevelButton.y and y <= self.createNewLevelButton.y + self.createNewLevelButton.height then
            -- Create a new level
            return "edit_level", nil
        end

        -- Check if back button was clicked
        if x >= 20 and x <= 150 and y >= screenHeight - 40 and y <= screenHeight - 10 then
            return "menu" -- Return to menu
        end

        -- Check level selection
        local gridStartX = (screenWidth - (self.gridSize * (self.previewSize + self.spacing))) / 2 + self.spacing / 2
        local gridStartY = 120

        local startIdx = (self.currentPage - 1) * self.levelsPerPage + 1
        local endIdx = math.min(startIdx + self.levelsPerPage - 1, #self.levels)

        for i = startIdx, endIdx do
            local level = self.levels[i]
            local idx = i - startIdx
            local row = math.floor(idx / self.gridSize)
            local col = idx % self.gridSize

            local levelX = gridStartX + col * (self.previewSize + self.spacing)
            local levelY = gridStartY + row * (self.previewSize + self.spacing + 30)

            -- Check if edit button was clicked
            if level.editButton and
                x >= level.editButton.x and x <= level.editButton.x + level.editButton.width and
                y >= level.editButton.y and y <= level.editButton.y + level.editButton.height then
                -- Edit the level
                return "edit_level", level.path
            end

            -- Check if level preview was clicked (play the level)
            if x >= levelX and x <= levelX + self.previewSize and
                y >= levelY and y <= levelY + self.previewSize and
                not (x >= level.editButton.x and x <= level.editButton.x + level.editButton.width and
                    y >= level.editButton.y and y <= level.editButton.y + level.editButton.height) then
                -- Level selected
                self.selectedLevel = level.path
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
