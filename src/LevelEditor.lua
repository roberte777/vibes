local json = require("vendor.json.json")

-- LevelEditor class
local LevelEditor = {}
LevelEditor.__index = LevelEditor

-- Create a new LevelEditor instance
function LevelEditor.new(levelPath)
    local self = setmetatable({}, LevelEditor)

    -- Level editor variables
    self.levelPath = levelPath
    self.editorState = "selectLevel" -- Default to the level selection screen
    self.levels = {}
    self.selectedLevel = nil
    self.currentMap = {}
    self.tileSize = 40
    self.editorTool = "path" -- "path" or "grass"
    self.isMouseDown = false
    self.newLevelName = ""
    self.newLevelDescription = ""
    self.editingField = nil
    self.waypoints = {}
    self.editingMode = "map" -- "map" or "waypoints"
    self.selectedWaypoint = nil
    self.isDraggingWaypoint = false
    self.mapSizeRows = 18
    self.mapSizeCols = 32
    self.levelName = "New Level"

    -- Initialize UI button positions for hit detection
    self.modeButton = { x = 20, y = 100, width = 180, height = 30 }
    self.saveButton = { x = 20, y = 140, width = 180, height = 30 }
    self.addWaypointButton = { x = 20, y = 180, width = 180, height = 30 }
    self.deleteWaypointButton = { x = 20, y = 220, width = 180, height = 30 }

    -- Map area offset variables
    self.mapOffsetX = 0
    self.mapOffsetY = 0

    -- Colors
    self.colors = {
        background = { 0.1, 0.1, 0.3, 1 },
        title = { 0.9, 0.7, 0.2, 1 },
        buttonNormal = { 0.2, 0.4, 0.8, 1 },
        buttonHover = { 0.3, 0.5, 0.9, 1 },
        buttonText = { 1, 1, 1, 1 },
        path = { 0.8, 0.7, 0.5, 1 },
        grass = { 0.3, 0.8, 0.3, 1 },
        grid = { 0.5, 0.5, 0.5, 0.3 },
        toolSelected = { 1, 1, 0, 1 }
    }

    -- Create editor buttons
    self.editorButtons = {
        back = {
            text = "Back to Menu",
            x = 20,
            y = 20,
            width = 150,
            height = 40,
            action = function()
                return "menu"
            end
        },
        backToLevelSelection = {
            text = "Level Select",
            x = 20,
            y = 70,
            width = 150,
            height = 40,
            action = function()
                self.editorState = "selectLevel"
                return nil
            end
        },
        path = {
            text = "Path Tool",
            x = 20,
            y = 120,
            width = 150,
            height = 40,
            action = function()
                self.editorTool = "path"
            end
        },
        grass = {
            text = "Grass Tool",
            x = 20,
            y = 170,
            width = 150,
            height = 40,
            action = function()
                self.editorTool = "grass"
            end
        },
        save = {
            text = "Save Level",
            x = 20,
            y = 220,
            width = 150,
            height = 40,
            saveMessage = "",
            messageTimer = 0,
            action = function()
                if self:saveLevel() then
                    -- Show success message temporarily
                    self.editorButtons.save.saveMessage = "Saved to: " ..
                        love.filesystem.getSaveDirectory() .. "/levels/custom"
                    self.editorButtons.save.messageTimer = 6 -- Show for 6 seconds
                else
                    self.editorButtons.save.saveMessage = "Failed to save!"
                    self.editorButtons.save.messageTimer = 3
                end
            end
        },
        export = {
            text = "Export Level",
            x = 20,
            y = 270,
            width = 150,
            height = 40,
            exportMessage = "",
            messageTimer = 0,
            action = function()
                if self.selectedLevel then
                    local content = love.filesystem.read("levels/custom/" .. self.selectedLevel)
                    if content then
                        local success = false
                        -- Attempt to save to the project directory
                        local file, err = io.open("levels/custom/" .. self.selectedLevel, "w")
                        if file then
                            file:write(content)
                            file:close()
                            success = true
                        end
                        if success then
                            self.editorButtons.export.exportMessage = "Exported to project directory"
                            self.editorButtons.export.messageTimer = 6
                        else
                            self.editorButtons.export.exportMessage = "Export failed!"
                            self.editorButtons.export.messageTimer = 3
                        end
                    else
                        self.editorButtons.export.exportMessage = "Failed to read level!"
                        self.editorButtons.export.messageTimer = 3
                    end
                end
            end
        },
        newLevel = {
            text = "New Level",
            x = 20,
            y = 320,
            width = 150,
            height = 40,
            action = function()
                self.editorState = "createLevel"
                self.newLevelName = ""
                self.newLevelDescription = ""
                self.editingField = "name"
            end
        }
    }

    -- Initialize editor
    self:loadLevelsList()
    self.editorFont = love.graphics.newFont(18)

    -- Create empty map if none exists
    if levelPath then
        self:loadLevel()
        self.editorState = "edit" -- If a level path is provided, go directly to edit mode
    end

    return self
end

-- Load all available levels from the levels directory
function LevelEditor:loadLevelsList()
    self.levels = {}
    -- Create the custom levels directory if it doesn't exist
    love.filesystem.createDirectory("levels/custom")

    local items = love.filesystem.getDirectoryItems("levels/custom")
    for _, file in ipairs(items) do
        if file:match("%.json$") then
            table.insert(self.levels, file)
        end
    end
end

-- Load a specific level from file
function LevelEditor:loadLevel()
    if not self.levelPath then return end

    local contents = love.filesystem.read(self.levelPath)
    if contents then
        local levelData = json.decode(contents)
        if levelData then
            self.map = levelData.map or {}
            self.waypoints = levelData.waypoints or {}
            self.levelName = levelData.name or "Unnamed Level"

            -- Update map size
            if #self.map > 0 then
                self.mapSizeRows = #self.map
                self.mapSizeCols = #self.map[1]
            end

            -- Update editor state to edit mode
            self.editorState = "edit"
        end
    end
end

-- Save the current map to the level file
function LevelEditor:saveLevel()
    if not self.levelPath then
        self.levelPath = "levels/custom/level1.json"
        -- Make sure the directory exists
        love.filesystem.createDirectory("levels/custom")
    end

    -- Create level data structure
    local levelData = {
        name = self.levelName,
        map = self.map,
        waypoints = self.waypoints,
        startPosition = { self.waypoints[1].y, self.waypoints[1].x },
        endPosition = { self.waypoints[#self.waypoints].y, self.waypoints[#self.waypoints].x },
        initialResources = 100,
        maxLives = 20,
        waves = {
            {
                waveNumber = 1,
                enemies = {
                    {
                        enemyType = "basic",
                        count = 10,
                        spawnInterval = 1.5
                    }
                }
            }
        }
    }

    -- Convert to JSON and save
    local jsonData = json.encode(levelData)
    love.filesystem.write(self.levelPath, jsonData)

    return true
end

-- Create a new level with default settings
function LevelEditor:createNewLevel(name, description)
    -- Ensure the custom levels directory exists
    love.filesystem.createDirectory("levels/custom")

    -- Generate a filename based on the level name
    local filename = name:lower():gsub(" ", "_") .. ".json"

    -- Create default waypoints
    local waypoints = {
        { x = 0,  y = 0 },
        { x = 31, y = 0 }
    }

    -- Create a default level structure
    local levelData = {
        level = #self.levels + 1,
        name = name,
        description = description,
        map = {
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111",
            "11111111111111111111111111111111"
        },
        waypoints = waypoints,
        startPosition = { 0, 0 },
        endPosition = { 0, 31 },
        waves = {
            {
                waveNumber = 1,
                enemies = {
                    {
                        enemyType = "basic",
                        count = 10,
                        spawnInterval = 1.5
                    }
                }
            }
        },
        initialResources = 100,
        maxLives = 20
    }

    -- Convert to JSON and save
    local success, jsonStr = pcall(json.encode, levelData)
    if not success then
        print("Failed to encode JSON: " .. tostring(jsonStr))
        return false
    end

    local success, message = pcall(love.filesystem.write, "levels/custom/" .. filename, jsonStr)
    if not success then
        print("Failed to write file: " .. tostring(message))
        return false
    end

    -- Update levels list and select the new level
    self:loadLevelsList()
    self.selectedLevel = filename
    self.levelPath = "levels/custom/" .. filename
    self.levelName = name
    self.map = levelData.map
    self.waypoints = waypoints

    -- Set to edit mode
    self.editorState = "edit"

    -- Update success message
    self.saveMessage = "Created level: " .. name
    self.saveMessageTimer = 3 -- Show for 3 seconds

    return true
end

-- Update function for level editor
function LevelEditor:update(dt)
    if self.isMouseDown then
        local mx, my = love.mouse.getPosition()

        -- Check if we're clicking on the map area
        if self.selectedLevel and mx > 200 and my > 50 then
            local mapX = math.floor((mx - 200) / self.tileSize) + 1
            local mapY = math.floor((my - 50) / self.tileSize) + 1

            -- Ensure we're within map bounds
            if self.currentMap[mapY] and mapX >= 1 and mapX <= #self.currentMap[mapY] then
                if self.editorTool == "path" then
                    self.currentMap[mapY][mapX] = 0
                elseif self.editorTool == "grass" then
                    self.currentMap[mapY][mapX] = 1
                end
            end
        end
    end

    -- Update save message timer
    if self.editorButtons.save.messageTimer > 0 then
        self.editorButtons.save.messageTimer = self.editorButtons.save.messageTimer - dt
        if self.editorButtons.save.messageTimer <= 0 then
            self.editorButtons.save.saveMessage = ""
        end
    end

    -- Update export message timer
    if self.editorButtons.export.messageTimer > 0 then
        self.editorButtons.export.messageTimer = self.editorButtons.export.messageTimer - dt
        if self.editorButtons.export.messageTimer <= 0 then
            self.editorButtons.export.exportMessage = ""
        end
    end

    -- Update save message timer
    if self.saveMessage and self.saveMessageTimer > 0 then
        self.saveMessageTimer = self.saveMessageTimer - dt
        if self.saveMessageTimer <= 0 then
            self.saveMessage = nil
        end
    end
end

-- Draw function for level editor
function LevelEditor:draw()
    love.graphics.setFont(self.editorFont)
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    if self.editorState == "selectLevel" then
        self:drawLevelSelector()
    elseif self.editorState == "createLevel" then
        self:drawCreateLevel()
    elseif self.editorState == "editMap" then
        self:drawMapEditor()
    else
        -- Main editor view
        -- Draw the map
        if self.map and #self.map > 0 then
            self:drawMap()
        end

        -- Draw waypoints if they exist
        if self.waypoints and #self.waypoints > 0 then
            self:drawWaypoints()
        end

        -- Draw UI
        self:drawUI(screenWidth, screenHeight)
    end

    -- Draw save message if active
    if self.saveMessage and self.saveMessageTimer > 0 then
        love.graphics.setColor(0, 1, 0, 1) -- Green for success
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.print(self.saveMessage, 20, 50)
    end
end

function LevelEditor:drawLevelSelector()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    -- Draw title
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.setColor(self.colors.title)
    love.graphics.print("Level Editor - Select a Level", screenWidth / 2 - 150, 20)

    love.graphics.setFont(self.editorFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Select a level to edit:", 100, 80)

    -- Draw level list
    if #self.levels == 0 then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("No levels found. Create a new level.", 100, 120)
    else
        for i, levelFile in ipairs(self.levels) do
            local y = 120 + (i - 1) * 40

            -- Draw level button background
            love.graphics.setColor(self.colors.buttonNormal)
            love.graphics.rectangle("fill", 100, y, 300, 30)

            -- Draw level name
            love.graphics.setColor(self.colors.buttonText)
            love.graphics.print(levelFile, 110, y + 5)
        end
    end

    -- Back button
    love.graphics.setColor(0.7, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", 20, 20, 150, 40, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Back to Menu", 35, 30)

    -- New level button
    love.graphics.setColor(0.3, 0.8, 0.3, 1)
    love.graphics.rectangle("fill", screenWidth - 170, 20, 150, 40, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("New Level", screenWidth - 155, 30)

    -- Store button positions for hit detection (instead of using editorButtons)
    self.backButton = { x = 20, y = 20, width = 150, height = 40 }
    self.newLevelButton = { x = screenWidth - 170, y = 20, width = 150, height = 40 }

    -- Store level positions for hit detection
    self.levelButtons = {}
    for i = 1, #self.levels do
        self.levelButtons[i] = {
            x = 100,
            y = 120 + (i - 1) * 40,
            width = 300,
            height = 30,
            levelFile = self.levels[i]
        }
    end
end

function LevelEditor:drawMapEditor()
    -- Draw sidebar tools
    for _, button in pairs(self.editorButtons) do
        -- Determine if button is selected (for tool buttons)
        local isSelected = false
        if button == self.editorButtons.path and self.editorTool == "path" then
            isSelected = true
        elseif button == self.editorButtons.grass and self.editorTool == "grass" then
            isSelected = true
        end

        -- Draw button background
        if isSelected then
            love.graphics.setColor(self.colors.toolSelected)
        else
            love.graphics.setColor(self.colors.buttonNormal)
        end

        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)

        -- Draw button text
        love.graphics.setColor(self.colors.buttonText)
        love.graphics.print(button.text, button.x + 10, button.y + 10)
    end

    -- Draw save message if active
    if self.editorButtons.save.messageTimer > 0 then
        if self.editorButtons.save.saveMessage:find("Saved to") then
            love.graphics.setColor(0, 1, 0, 1) -- Green for success
        else
            love.graphics.setColor(1, 0, 0, 1) -- Red for failure
        end
        love.graphics.print(self.editorButtons.save.saveMessage,
            self.editorButtons.save.x,
            self.editorButtons.save.y + self.editorButtons.save.height + 5)
    end

    -- Draw export message if active
    if self.editorButtons.export.messageTimer > 0 then
        if self.editorButtons.export.exportMessage:find("Exported") then
            love.graphics.setColor(0, 1, 0, 1) -- Green for success
        else
            love.graphics.setColor(1, 0, 0, 1) -- Red for failure
        end
        love.graphics.print(self.editorButtons.export.exportMessage,
            self.editorButtons.export.x,
            self.editorButtons.export.y + self.editorButtons.export.height + 5)
    end

    -- Draw level name
    love.graphics.setColor(self.colors.title)
    love.graphics.print("Editing: " .. self.selectedLevel, 200, 20)

    -- Draw the map grid
    if self.currentMap and #self.currentMap > 0 then
        for y = 1, #self.currentMap do
            for x = 1, #self.currentMap[y] do
                local tileX = 200 + (x - 1) * self.tileSize
                local tileY = 50 + (y - 1) * self.tileSize

                -- Draw tile
                if self.currentMap[y][x] == 0 then
                    love.graphics.setColor(self.colors.path)
                else
                    love.graphics.setColor(self.colors.grass)
                end

                love.graphics.rectangle("fill", tileX, tileY, self.tileSize, self.tileSize)

                -- Draw grid lines
                love.graphics.setColor(self.colors.grid)
                love.graphics.rectangle("line", tileX, tileY, self.tileSize, self.tileSize)
            end
        end
    end
end

function LevelEditor:drawCreateLevel()
    -- Implement the UI for creating a new level
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Enter level name:", 100, 80)
    love.graphics.print("Enter level description:", 100, 160)

    -- Draw input fields
    if self.editingField == "name" then
        love.graphics.setColor(0.3, 0.7, 1, 1) -- Highlight active field
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
    end
    love.graphics.rectangle("fill", 100, 110, 300, 30)

    if self.editingField == "description" then
        love.graphics.setColor(0.3, 0.7, 1, 1) -- Highlight active field
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
    end
    love.graphics.rectangle("fill", 100, 190, 300, 30)

    -- Draw text in input fields
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.newLevelName, 105, 115)
    love.graphics.print(self.newLevelDescription, 105, 195)

    -- Draw buttons
    love.graphics.setColor(self.colors.buttonNormal)
    love.graphics.rectangle("fill", 100, 240, 150, 40) -- Create button

    love.graphics.rectangle("fill", 260, 240, 150, 40) -- Cancel button

    love.graphics.setColor(self.colors.buttonText)
    love.graphics.print("Create Level", 115, 250)
    love.graphics.print("Cancel", 305, 250)

    -- Show instruction
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Press Tab to switch fields, Enter to create", 100, 290)
    love.graphics.print("Press Escape to cancel", 100, 315)
end

function LevelEditor:mousepressed(x, y, button)
    if button == 1 then -- Left click
        if self.editorState == "selectLevel" then
            -- Check back button
            if self.backButton and
                x >= self.backButton.x and x <= self.backButton.x + self.backButton.width and
                y >= self.backButton.y and y <= self.backButton.y + self.backButton.height then
                return "menu"
            end

            -- Check new level button
            if self.newLevelButton and
                x >= self.newLevelButton.x and x <= self.newLevelButton.x + self.newLevelButton.width and
                y >= self.newLevelButton.y and y <= self.newLevelButton.y + self.newLevelButton.height then
                self.editorState = "createLevel"
                self.newLevelName = ""
                self.newLevelDescription = ""
                self.editingField = "name"
                return
            end

            -- Check level selection
            if self.levelButtons then
                for i, button in ipairs(self.levelButtons) do
                    if x >= button.x and x <= button.x + button.width and
                        y >= button.y and y <= button.y + button.height then
                        -- Level selected
                        self.levelPath = "levels/custom/" .. button.levelFile
                        self:loadLevel()
                        return
                    end
                end
            end
        elseif self.editorState == "createLevel" then
            -- Handle input field selection
            if x >= 100 and x <= 400 and y >= 110 and y <= 140 then
                self.editingField = "name"
            elseif x >= 100 and x <= 400 and y >= 190 and y <= 220 then
                self.editingField = "description"
            end

            -- Handle Create button click
            if x >= 100 and x <= 250 and y >= 240 and y <= 280 then
                if self.newLevelName:len() > 0 then
                    -- Create the new level
                    if self:createNewLevel(self.newLevelName, self.newLevelDescription) then
                        self.editorState = "edit"
                    end
                end
            end

            -- Handle Cancel button click
            if x >= 260 and x <= 410 and y >= 240 and y <= 280 then
                self.editorState = "selectLevel"
            end
        elseif self.editorState == "editMap" then
            -- Handle editor tool buttons
            for _, button in pairs(self.editorButtons) do
                if x >= button.x and x <= button.x + button.width and
                    y >= button.y and y <= button.y + button.height then
                    local result = button.action()
                    if result then
                        return result
                    end
                    break
                end
            end
        else
            -- Main editor mode - handle UI buttons first
            if self.backButton and x >= self.backButton.x and x <= self.backButton.x + self.backButton.width and
                y >= self.backButton.y and y <= self.backButton.y + self.backButton.height then
                -- Return to level selection
                self.editorState = "selectLevel"
                return
            end

            if self.mainMenuButton and x >= self.mainMenuButton.x and x <= self.mainMenuButton.x + self.mainMenuButton.width and
                y >= self.mainMenuButton.y and y <= self.mainMenuButton.y + self.mainMenuButton.height then
                -- Return to main menu
                return "menu"
            end

            if self.modeButton and x >= self.modeButton.x and x <= self.modeButton.x + self.modeButton.width and
                y >= self.modeButton.y and y <= self.modeButton.y + self.modeButton.height then
                -- Toggle edit mode
                self.editingMode = self.editingMode == "map" and "waypoints" or "map"
                self.selectedWaypoint = nil
                return
            end

            if self.saveButton and x >= self.saveButton.x and x <= self.saveButton.x + self.saveButton.width and
                y >= self.saveButton.y and y <= self.saveButton.y + self.saveButton.height then
                -- Save level
                self:saveLevel()
                return
            end

            if self.editingMode == "waypoints" then
                if self.addWaypointButton and
                    x >= self.addWaypointButton.x and x <= self.addWaypointButton.x + self.addWaypointButton.width and
                    y >= self.addWaypointButton.y and y <= self.addWaypointButton.y + self.addWaypointButton.height then
                    -- Add new waypoint at the end (before the final waypoint)
                    if #self.waypoints >= 2 then
                        local lastPoint = self.waypoints[#self.waypoints]
                        local secondLastPoint = self.waypoints[#self.waypoints - 1]

                        -- Create midpoint between second-last and last waypoint
                        local newX = (lastPoint.x + secondLastPoint.x) / 2
                        local newY = (lastPoint.y + secondLastPoint.y) / 2

                        -- Insert before the last waypoint
                        table.insert(self.waypoints, #self.waypoints, { x = newX, y = newY })
                        self.selectedWaypoint = #self.waypoints - 1
                    end
                    return
                end

                if self.selectedWaypoint and self.deleteWaypointButton and
                    x >= self.deleteWaypointButton.x and x <= self.deleteWaypointButton.x + self.deleteWaypointButton.width and
                    y >= self.deleteWaypointButton.y and y <= self.deleteWaypointButton.y + self.deleteWaypointButton.height then
                    -- Don't allow deleting first or last waypoint
                    if self.selectedWaypoint > 1 and self.selectedWaypoint < #self.waypoints then
                        table.remove(self.waypoints, self.selectedWaypoint)
                        self.selectedWaypoint = nil
                    end
                    return
                end
            end

            -- Check map/waypoint interactions
            if self.mapOffsetX and self.mapOffsetY then
                -- Convert mouse position to map grid coordinates
                local mapX = math.floor((x - self.mapOffsetX) / self.tileSize) + 1
                local mapY = math.floor((y - self.mapOffsetY) / self.tileSize) + 1

                -- Make sure click is within map bounds
                if mapX >= 1 and mapX <= #self.map[1] and mapY >= 1 and mapY <= #self.map then
                    if self.editingMode == "map" then
                        -- Toggle tile type (0 = path, 1 = grass)
                        local row = self.map[mapY]
                        local currentTile = row:sub(mapX, mapX)
                        local newTile = currentTile == "1" and "0" or "1"
                        self.map[mapY] = row:sub(1, mapX - 1) .. newTile .. row:sub(mapX + 1)
                    else
                        -- Check if clicked on a waypoint
                        self.selectedWaypoint = nil
                        for i, point in ipairs(self.waypoints) do
                            local wpX = self.mapOffsetX + point.x * self.tileSize + self.tileSize / 2
                            local wpY = self.mapOffsetY + point.y * self.tileSize + self.tileSize / 2

                            -- Check if click is within waypoint radius
                            local distance = math.sqrt((x - wpX) ^ 2 + (y - wpY) ^ 2)
                            if distance <= 12 then
                                self.selectedWaypoint = i
                                self.isDraggingWaypoint = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

function LevelEditor:mousereleased(x, y, button)
    if button == 1 then
        self.isDraggingWaypoint = false
    end
end

function LevelEditor:textinput(text)
    if self.editorState == "createLevel" then
        if self.editingField == "name" then
            self.newLevelName = self.newLevelName .. text
        elseif self.editingField == "description" then
            self.newLevelDescription = self.newLevelDescription .. text
        end
    end
end

function LevelEditor:keypressed(key)
    if self.editorState == "createLevel" then
        if key == "return" or key == "kpenter" then
            -- Create level on Enter key if name is present
            if self.newLevelName:len() > 0 then
                if self:createNewLevel(self.newLevelName, self.newLevelDescription) then
                    -- Successfully created level, switch to edit mode
                    self.editorState = "edit"
                end
            end
        elseif key == "tab" then
            -- Switch between name and description fields
            if self.editingField == "name" then
                self.editingField = "description"
            elseif self.editingField == "description" then
                self.editingField = "name"
            end
        elseif key == "backspace" then
            -- Delete last character
            if self.editingField == "name" then
                self.newLevelName = self.newLevelName:sub(1, -2)
            elseif self.editingField == "description" then
                self.newLevelDescription = self.newLevelDescription:sub(1, -2)
            end
        elseif key == "escape" then
            -- Cancel and return to level selection
            self.editorState = "selectLevel"
        end
    elseif self.editorState == "edit" then
        -- Allow escaping from edit mode back to level selection
        if key == "escape" then
            self.editorState = "selectLevel"
        end
    end
end

function LevelEditor:createEmptyLevel()
    -- Create an empty map
    self.map = {}
    for i = 1, self.mapSizeRows do
        local row = ""
        for j = 1, self.mapSizeCols do
            row = row .. "1" -- Default to grass
        end
        table.insert(self.map, row)
    end

    -- Create default waypoints (start and end only)
    self.waypoints = {
        { x = 0,                    y = 0 },
        { x = self.mapSizeCols - 1, y = 0 }
    }

    -- Set default level data
    self.levelName = "New Level"

    -- Set editor state
    self.editorState = "edit"
end

function LevelEditor:drawWaypoints()
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

            if i == self.selectedWaypoint then
                -- Selected waypoint
                love.graphics.setColor(1, 1, 1, 1) -- White
                love.graphics.circle("fill", x, y, 10)
                love.graphics.setColor(0, 0, 1, 1) -- Blue
                love.graphics.circle("line", x, y, 12)
            elseif i == 1 then
                -- Start waypoint
                love.graphics.setColor(0, 1, 0, 1) -- Green
                love.graphics.circle("fill", x, y, 8)
            elseif i == #self.waypoints then
                -- End waypoint
                love.graphics.setColor(1, 0, 0, 1) -- Red
                love.graphics.circle("fill", x, y, 8)
            else
                -- Middle waypoint
                love.graphics.setColor(1, 1, 0, 1) -- Yellow
                love.graphics.circle("fill", x, y, 6)
            end

            -- Draw waypoint number
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setFont(love.graphics.newFont(12))
            local numWidth = love.graphics.getFont():getWidth(tostring(i))
            love.graphics.print(tostring(i), x - numWidth / 2, y - 6)
        end
    end
end

function LevelEditor:drawUI(screenWidth, screenHeight)
    -- UI background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", 10, 60, 200, 180, 5, 5)

    -- Title
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Editor Tools", 20, 70)

    -- Back to level selection button
    self.backButton = { x = 20, y = 10, width = 100, height = 30 }
    love.graphics.setColor(0.7, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", self.backButton.x, self.backButton.y,
        self.backButton.width, self.backButton.height, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Back", self.backButton.x + 35, self.backButton.y + 5)

    -- Main menu button
    self.mainMenuButton = { x = 130, y = 10, width = 140, height = 30 }
    love.graphics.setColor(0.7, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", self.mainMenuButton.x, self.mainMenuButton.y,
        self.mainMenuButton.width, self.mainMenuButton.height, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Main Menu", self.mainMenuButton.x + 30, self.mainMenuButton.y + 5)

    -- Update button positions
    self.modeButton = { x = 20, y = 100, width = 180, height = 30 }
    self.saveButton = { x = 20, y = 140, width = 180, height = 30 }
    self.addWaypointButton = { x = 20, y = 180, width = 180, height = 30 }
    self.deleteWaypointButton = { x = 20, y = 220, width = 180, height = 30 }

    -- Mode toggle button
    love.graphics.setColor(0.3, 0.6, 0.9, 1)
    love.graphics.rectangle("fill", self.modeButton.x, self.modeButton.y, self.modeButton.width, self.modeButton.height,
        5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    local toggleText = self.editingMode == "map" and "Switch to Waypoints" or "Switch to Map"
    local textWidth = love.graphics.getFont():getWidth(toggleText)
    love.graphics.print(toggleText, self.modeButton.x + (self.modeButton.width - textWidth) / 2, self.modeButton.y + 5)

    -- Save button
    love.graphics.setColor(0.3, 0.8, 0.3, 1)
    love.graphics.rectangle("fill", self.saveButton.x, self.saveButton.y, self.saveButton.width, self.saveButton.height,
        5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    local saveText = "Save Level"
    textWidth = love.graphics.getFont():getWidth(saveText)
    love.graphics.print(saveText, self.saveButton.x + (self.saveButton.width - textWidth) / 2, self.saveButton.y + 5)

    -- Add waypoint button (only in waypoint mode)
    if self.editingMode == "waypoints" then
        love.graphics.setColor(0.9, 0.6, 0.3, 1)
        love.graphics.rectangle("fill", self.addWaypointButton.x, self.addWaypointButton.y,
            self.addWaypointButton.width, self.addWaypointButton.height, 5, 5)
        love.graphics.setColor(1, 1, 1, 1)
        local addText = "Add Waypoint"
        textWidth = love.graphics.getFont():getWidth(addText)
        love.graphics.print(addText, self.addWaypointButton.x + (self.addWaypointButton.width - textWidth) / 2,
            self.addWaypointButton.y + 5)

        -- Delete waypoint button (only if a waypoint is selected)
        if self.selectedWaypoint then
            love.graphics.setColor(0.9, 0.3, 0.3, 1)
            love.graphics.rectangle("fill", self.deleteWaypointButton.x, self.deleteWaypointButton.y,
                self.deleteWaypointButton.width, self.deleteWaypointButton.height, 5, 5)
            love.graphics.setColor(1, 1, 1, 1)
            local deleteText = "Delete Waypoint"
            textWidth = love.graphics.getFont():getWidth(deleteText)
            love.graphics.print(deleteText,
                self.deleteWaypointButton.x + (self.deleteWaypointButton.width - textWidth) / 2,
                self.deleteWaypointButton.y + 5)
        end
    end

    -- Instructions
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    if self.editingMode == "map" then
        love.graphics.print("Click to toggle tiles", 20, 190)
    else
        love.graphics.print("Drag to move waypoints", 20, 260)
        love.graphics.print("Click to select", 20, 280)
    end
end

function LevelEditor:mousemoved(x, y, dx, dy)
    if self.editingMode == "waypoints" and self.isDraggingWaypoint and self.selectedWaypoint then
        local mapX = (x - self.mapOffsetX) / self.tileSize
        local mapY = (y - self.mapOffsetY) / self.tileSize

        -- Restrict to map bounds
        mapX = math.max(0, math.min(mapX, #self.map[1] - 1))
        mapY = math.max(0, math.min(mapY, #self.map - 1))

        -- Update waypoint position
        self.waypoints[self.selectedWaypoint].x = mapX
        self.waypoints[self.selectedWaypoint].y = mapY
    end
end

function LevelEditor:drawMap()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    -- Calculate the map dimensions
    local mapRows = #self.map
    local mapCols = #self.map[1]

    -- Calculate the centering offset
    local offsetX = (screenWidth - (mapCols * self.tileSize)) / 2
    local offsetY = (screenHeight - (mapRows * self.tileSize)) / 2

    -- Store offsets for hit detection
    self.mapOffsetX = offsetX
    self.mapOffsetY = offsetY

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

return LevelEditor
