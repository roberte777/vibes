local json = require("vendor.json.json")

-- LevelEditor class
local LevelEditor = {}
LevelEditor.__index = LevelEditor

-- Create a new LevelEditor instance
function LevelEditor.new()
    local self = setmetatable({}, LevelEditor)

    -- Level editor variables
    self.editorState = "selectLevel"
    self.levels = {}
    self.selectedLevel = nil
    self.currentMap = {}
    self.tileSize = 32
    self.editorTool = "path" -- "path" or "grass"
    self.isMouseDown = false
    self.newLevelName = ""
    self.newLevelDescription = ""
    self.editingField = nil

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
function LevelEditor:loadLevel(levelFilename)
    local content = love.filesystem.read("levels/custom/" .. levelFilename)
    if content then
        -- Use the JSON library to parse the level data
        local success, levelData = pcall(json.decode, content)

        if success and levelData and levelData.map then
            self.selectedLevel = levelFilename
            self.currentMap = {}

            -- Copy the map data
            for i, row in ipairs(levelData.map) do
                self.currentMap[i] = {}
                for j = 1, #row do
                    local char = row:sub(j, j)
                    self.currentMap[i][j] = tonumber(char)
                end
            end

            return true
        end
    end
    return false
end

-- Save the current map to the level file
function LevelEditor:saveLevel()
    if not self.selectedLevel then return false end

    -- Ensure the custom levels directory exists
    love.filesystem.createDirectory("levels/custom")

    -- Debug output
    print("Attempting to save to: " .. love.filesystem.getSaveDirectory() .. "/levels/custom/" .. self.selectedLevel)

    -- Check if we can write to the directory
    local success, message = pcall(function()
        local testFile = "levels/custom/test_write.tmp"
        love.filesystem.write(testFile, "test")
        local exists = love.filesystem.getInfo(testFile)
        if exists then
            love.filesystem.remove(testFile)
            print("Write test successful")
        else
            print("Failed to write test file")
        end
    end)

    if not success then
        print("Write permission test failed: " .. tostring(message))
    end

    -- Prepare level data
    local levelData = {}

    -- Try to read and parse existing data
    local content = love.filesystem.read("levels/custom/" .. self.selectedLevel)
    if content then
        local success, existingData = pcall(json.decode, content)
        if success and existingData then
            levelData = existingData
        end
    end

    -- Update the map data
    local mapStrings = {}
    for i, row in ipairs(self.currentMap) do
        local rowStr = ""
        for j, tile in ipairs(row) do
            rowStr = rowStr .. tostring(tile)
        end
        mapStrings[i] = rowStr
    end

    levelData.map = mapStrings

    -- Convert back to JSON and save
    local success, jsonStr = pcall(json.encode, levelData)
    if not success then
        print("Failed to encode JSON: " .. tostring(jsonStr))
        return false
    end

    local success, message = pcall(love.filesystem.write, "levels/custom/" .. self.selectedLevel, jsonStr)
    if not success then
        print("Failed to write file: " .. tostring(message))
        return false
    end

    return true
end

-- Create a new level with default settings
function LevelEditor:createNewLevel(name, description)
    -- Ensure the custom levels directory exists
    love.filesystem.createDirectory("levels/custom")

    -- Generate a filename based on the level name
    local filename = name:lower():gsub(" ", "_") .. ".json"

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
    self:loadLevel(filename)

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
end

-- Draw function for level editor
function LevelEditor:draw()
    love.graphics.setFont(self.editorFont)

    -- Draw editor title
    love.graphics.setColor(self.colors.title)
    love.graphics.print("Level Editor", 20, 20)

    if self.editorState == "selectLevel" then
        self:drawLevelSelector()
    elseif self.editorState == "editMap" then
        self:drawMapEditor()
    elseif self.editorState == "createLevel" then
        self:drawCreateLevel()
    end
end

function LevelEditor:drawLevelSelector()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Select a level to edit:", 100, 80)

    -- Draw level list
    for i, levelFile in ipairs(self.levels) do
        local y = 120 + (i - 1) * 40
        love.graphics.setColor(self.colors.buttonNormal)
        love.graphics.rectangle("fill", 100, y, 300, 30)

        love.graphics.setColor(self.colors.buttonText)
        love.graphics.print(levelFile, 110, y + 5)
    end

    -- Back button
    love.graphics.setColor(self.colors.buttonNormal)
    love.graphics.rectangle("fill", self.editorButtons.back.x, self.editorButtons.back.y,
        self.editorButtons.back.width, self.editorButtons.back.height)
    love.graphics.setColor(self.colors.buttonText)
    love.graphics.print(self.editorButtons.back.text, self.editorButtons.back.x + 10, self.editorButtons.back.y + 10)

    -- New level button
    love.graphics.setColor(self.colors.buttonNormal)
    love.graphics.rectangle("fill", self.editorButtons.newLevel.x, self.editorButtons.newLevel.y,
        self.editorButtons.newLevel.width, self.editorButtons.newLevel.height)
    love.graphics.setColor(self.colors.buttonText)
    love.graphics.print(self.editorButtons.newLevel.text, self.editorButtons.newLevel.x + 10,
        self.editorButtons.newLevel.y + 10)
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
end

function LevelEditor:mousepressed(x, y, button)
    if button == 1 then -- Left click
        if self.editorState == "selectLevel" then
            -- Handle back button click
            if x >= self.editorButtons.back.x and x <= self.editorButtons.back.x + self.editorButtons.back.width and
                y >= self.editorButtons.back.y and y <= self.editorButtons.back.y + self.editorButtons.back.height then
                return self.editorButtons.back.action()
            end

            -- Check if new level button was clicked
            if x >= self.editorButtons.newLevel.x and x <= self.editorButtons.newLevel.x + self.editorButtons.newLevel.width and
                y >= self.editorButtons.newLevel.y and y <= self.editorButtons.newLevel.y + self.editorButtons.newLevel.height then
                self.editorButtons.newLevel.action()
                return nil
            end

            -- Handle level selection
            for i, levelFile in ipairs(self.levels) do
                local levelY = 120 + (i - 1) * 40
                if x > 100 and x < 400 and y > levelY and y < levelY + 30 then
                    if self:loadLevel(levelFile) then
                        self.editorState = "editMap"
                    end
                    break
                end
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

            -- Handle map clicks
            if self.currentMap and #self.currentMap > 0 then
                for mapY = 1, #self.currentMap do
                    for mapX = 1, #self.currentMap[mapY] do
                        local tileX = 200 + (mapX - 1) * self.tileSize
                        local tileY = 50 + (mapY - 1) * self.tileSize

                        if x >= tileX and x < tileX + self.tileSize and
                            y >= tileY and y < tileY + self.tileSize then
                            -- Set tile type based on selected tool
                            if self.editorTool == "path" then
                                self.currentMap[mapY][mapX] = 0
                            elseif self.editorTool == "grass" then
                                self.currentMap[mapY][mapX] = 1
                            end
                            self.isMouseDown = true
                        end
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
                        self.editorState = "editMap"
                    end
                end
            end

            -- Handle Cancel button click
            if x >= 260 and x <= 410 and y >= 240 and y <= 280 then
                self.editorState = "selectLevel"
            end
        end
    end
    return nil
end

function LevelEditor:mousereleased(x, y, button)
    if button == 1 then -- Left click
        self.isMouseDown = false
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
        if key == "return" or key == "tab" then
            if self.editingField == "name" then
                self.editingField = "description"
            elseif self.editingField == "description" then
                self.editingField = "name"
            end
        elseif key == "backspace" then
            if self.editingField == "name" then
                self.newLevelName = self.newLevelName:sub(1, -2)
            elseif self.editingField == "description" then
                self.newLevelDescription = self.newLevelDescription:sub(1, -2)
            end
        elseif key == "escape" then
            self.editorState = "selectLevel"
        end
    end
end

return LevelEditor
