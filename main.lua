-- Goblin Blasters
-- Tower Defense Game

-- Import JSON library
local json = require("vendor.json.json")

-- Menu state management
local gameState = "menu"
local buttons = {}
local selectedButton = 1

-- Level editor variables
local editorState = "selectLevel"
local levels = {}
local selectedLevel = nil
local currentMap = {}
local tileSize = 32
local editorTool = "path" -- "path" or "grass"
local isMouseDown = false
local editorButtons = {}
local newLevelName = ""
local newLevelDescription = ""
local editingField = nil

-- Colors
local colors = {
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

-- Load all available levels from the levels directory
function loadLevelsList()
    levels = {}
    local items = love.filesystem.getDirectoryItems("levels")
    for _, file in ipairs(items) do
        if file:match("%.json$") then
            table.insert(levels, file)
        end
    end
end

-- Load a specific level from file
function loadLevel(levelFilename)
    local content = love.filesystem.read("levels/" .. levelFilename)
    if content then
        -- Use the JSON library to parse the level data
        local success, levelData = pcall(json.decode, content)

        if success and levelData and levelData.map then
            selectedLevel = levelFilename
            currentMap = {}

            -- Copy the map data
            for i, row in ipairs(levelData.map) do
                currentMap[i] = {}
                for j = 1, #row do
                    local char = row:sub(j, j)
                    currentMap[i][j] = tonumber(char)
                end
            end

            return true
        end
    end
    return false
end

-- Save the current map to the level file
function saveLevel()
    if not selectedLevel then return false end

    -- Ensure the levels directory exists
    love.filesystem.createDirectory("levels")

    -- Debug output
    print("Attempting to save to: " .. love.filesystem.getSaveDirectory() .. "/levels/" .. selectedLevel)

    -- Check if we can write to the directory
    local success, message = pcall(function()
        local testFile = "levels/test_write.tmp"
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
    local content = love.filesystem.read("levels/" .. selectedLevel)
    if content then
        local success, existingData = pcall(json.decode, content)
        if success and existingData then
            levelData = existingData
        end
    end

    -- Update the map data
    local mapStrings = {}
    for i, row in ipairs(currentMap) do
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

    local success, message = pcall(love.filesystem.write, "levels/" .. selectedLevel, jsonStr)
    if not success then
        print("Failed to write file: " .. tostring(message))
        return false
    end

    return true
end

-- Create a new level with default settings
function createNewLevel(name, description)
    -- Ensure the levels directory exists
    love.filesystem.createDirectory("levels")

    -- Generate a filename based on the level name
    local filename = name:lower():gsub(" ", "_") .. ".json"

    -- Create a default level structure
    local levelData = {
        level = #levels + 1,
        name = name,
        description = description,
        map = {
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000",
            "00000000000000000000000000000000"
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

    local success, message = pcall(love.filesystem.write, "levels/" .. filename, jsonStr)
    if not success then
        print("Failed to write file: " .. tostring(message))
        return false
    end

    -- Update levels list and select the new level
    loadLevelsList()
    selectedLevel = filename
    loadLevel(filename)

    return true
end

function love.load()
    -- Set up fonts
    titleFont = love.graphics.newFont(48)
    menuFont = love.graphics.newFont(24)
    editorFont = love.graphics.newFont(18)

    -- Create buttons
    buttons = {
        { text = "Start Game", action = function() gameState = "game" end },
        { text = "Load Game",  action = function() gameState = "load" end },
        {
            text = "Level Creator",
            action = function()
                gameState = "editor"
                editorState = "selectLevel"
                loadLevelsList()
            end
        },
        { text = "Exit", action = function() love.event.quit() end }
    }

    -- Create editor buttons
    editorButtons = {
        back = {
            text = "Back to Menu",
            x = 20,
            y = 20,
            width = 150,
            height = 40,
            action = function()
                gameState = "menu"
                selectedLevel = nil
                currentMap = {}
                editorState = "selectLevel"
            end
        },
        path = {
            text = "Path Tool",
            x = 20,
            y = 80,
            width = 150,
            height = 40,
            action = function()
                editorTool = "path"
            end
        },
        grass = {
            text = "Grass Tool",
            x = 20,
            y = 130,
            width = 150,
            height = 40,
            action = function()
                editorTool = "grass"
            end
        },
        save = {
            text = "Save Level",
            x = 20,
            y = 180,
            width = 150,
            height = 40,
            saveMessage = "",
            messageTimer = 0,
            action = function()
                if saveLevel() then
                    -- Show success message temporarily
                    editorButtons.save.saveMessage = "Saved to: " .. love.filesystem.getSaveDirectory() .. "/levels"
                    editorButtons.save.messageTimer = 6 -- Show for 6 seconds
                else
                    editorButtons.save.saveMessage = "Failed to save!"
                    editorButtons.save.messageTimer = 3
                end
            end
        },
        export = {
            text = "Export Level",
            x = 20,
            y = 230,
            width = 150,
            height = 40,
            exportMessage = "",
            messageTimer = 0,
            action = function()
                if selectedLevel then
                    local content = love.filesystem.read("levels/" .. selectedLevel)
                    if content then
                        local success = false
                        -- Attempt to save to the project directory
                        local file, err = io.open("levels/" .. selectedLevel, "w")
                        if file then
                            file:write(content)
                            file:close()
                            success = true
                        end
                        if success then
                            editorButtons.export.exportMessage = "Exported to project directory"
                            editorButtons.export.messageTimer = 6
                        else
                            editorButtons.export.exportMessage = "Export failed!"
                            editorButtons.export.messageTimer = 3
                        end
                    else
                        editorButtons.export.exportMessage = "Failed to read level!"
                        editorButtons.export.messageTimer = 3
                    end
                end
            end
        },
        newLevel = {
            text = "New Level",
            x = 20,
            y = 280,
            width = 150,
            height = 40,
            action = function()
                editorState = "createLevel"
                newLevelName = ""
                newLevelDescription = ""
                editingField = "name"
            end
        }
    }

    -- Text input handlers
    love.keyboard.setKeyRepeat(true)
end

function love.update(dt)
    if gameState == "menu" then
        -- Menu logic here
    elseif gameState == "game" then
        -- Game logic will go here
    elseif gameState == "load" then
        -- Load game logic will go here
    elseif gameState == "editor" then
        -- Level editor logic
        if isMouseDown then
            local mx, my = love.mouse.getPosition()

            -- Check if we're clicking on the map area
            if selectedLevel and mx > 200 and my > 50 then
                local mapX = math.floor((mx - 200) / tileSize) + 1
                local mapY = math.floor((my - 50) / tileSize) + 1

                -- Ensure we're within map bounds
                if currentMap[mapY] and mapX >= 1 and mapX <= #currentMap[mapY] then
                    if editorTool == "path" then
                        currentMap[mapY][mapX] = 0
                    elseif editorTool == "grass" then
                        currentMap[mapY][mapX] = 1
                    end
                end
            end
        end

        -- Update save message timer
        if editorButtons.save.messageTimer > 0 then
            editorButtons.save.messageTimer = editorButtons.save.messageTimer - dt
            if editorButtons.save.messageTimer <= 0 then
                editorButtons.save.saveMessage = ""
            end
        end

        -- Update export message timer
        if editorButtons.export.messageTimer > 0 then
            editorButtons.export.messageTimer = editorButtons.export.messageTimer - dt
            if editorButtons.export.messageTimer <= 0 then
                editorButtons.export.exportMessage = ""
            end
        end
    end
end

function love.draw()
    -- Set background
    love.graphics.setBackgroundColor(colors.background)

    if gameState == "menu" then
        drawMenu()
    elseif gameState == "game" then
        love.graphics.print("Game screen - not implemented yet", 100, 100)
    elseif gameState == "load" then
        love.graphics.print("Load game screen - not implemented yet", 100, 100)
    elseif gameState == "editor" then
        drawLevelEditor()
    end
end

function drawMenu()
    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() / 2

    -- Draw title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.title)
    local title = "Goblin Blasters"
    local titleWidth = titleFont:getWidth(title)
    love.graphics.print(title, centerX - titleWidth / 2, centerY - 200)

    -- Draw buttons
    love.graphics.setFont(menuFont)
    for i, button in ipairs(buttons) do
        local buttonWidth = 200
        local buttonHeight = 50
        local buttonX = centerX - buttonWidth / 2
        local buttonY = centerY - 50 + (i - 1) * 70

        -- Check if mouse is over the button
        local mx, my = love.mouse.getPosition()
        local hover = mx > buttonX and mx < buttonX + buttonWidth and
            my > buttonY and my < buttonY + buttonHeight

        -- Set button color based on hover state
        if i == selectedButton then
            love.graphics.setColor(colors.buttonHover)
        else
            love.graphics.setColor(colors.buttonNormal)
        end

        -- Draw button
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 10, 10)

        -- Draw button text
        love.graphics.setColor(colors.buttonText)
        local textWidth = menuFont:getWidth(button.text)
        love.graphics.print(button.text, buttonX + buttonWidth / 2 - textWidth / 2, buttonY + 10)
    end
end

function drawLevelEditor()
    love.graphics.setFont(editorFont)

    -- Draw editor title
    love.graphics.setColor(colors.title)
    love.graphics.print("Level Editor", 20, 20)

    if editorState == "selectLevel" then
        drawLevelSelector()
    elseif editorState == "editMap" then
        drawMapEditor()
    elseif editorState == "createLevel" then
        drawCreateLevel()
    end
end

function drawLevelSelector()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Select a level to edit:", 100, 80)

    -- Draw level list
    for i, levelFile in ipairs(levels) do
        local y = 120 + (i - 1) * 40
        love.graphics.setColor(colors.buttonNormal)
        love.graphics.rectangle("fill", 100, y, 300, 30)

        love.graphics.setColor(colors.buttonText)
        love.graphics.print(levelFile, 110, y + 5)
    end

    -- Back button
    love.graphics.setColor(colors.buttonNormal)
    love.graphics.rectangle("fill", editorButtons.back.x, editorButtons.back.y,
        editorButtons.back.width, editorButtons.back.height)
    love.graphics.setColor(colors.buttonText)
    love.graphics.print(editorButtons.back.text, editorButtons.back.x + 10, editorButtons.back.y + 10)
end

function drawMapEditor()
    -- Draw sidebar tools
    for _, button in pairs(editorButtons) do
        -- Determine if button is selected (for tool buttons)
        local isSelected = false
        if button == editorButtons.path and editorTool == "path" then
            isSelected = true
        elseif button == editorButtons.grass and editorTool == "grass" then
            isSelected = true
        end

        -- Draw button background
        if isSelected then
            love.graphics.setColor(colors.toolSelected)
        else
            love.graphics.setColor(colors.buttonNormal)
        end

        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)

        -- Draw button text
        love.graphics.setColor(colors.buttonText)
        love.graphics.print(button.text, button.x + 10, button.y + 10)
    end

    -- Draw save message if active
    if editorButtons.save.messageTimer > 0 then
        if editorButtons.save.saveMessage:find("Saved to") then
            love.graphics.setColor(0, 1, 0, 1) -- Green for success
        else
            love.graphics.setColor(1, 0, 0, 1) -- Red for failure
        end
        love.graphics.print(editorButtons.save.saveMessage,
            editorButtons.save.x,
            editorButtons.save.y + editorButtons.save.height + 5)
    end

    -- Draw export message if active
    if editorButtons.export.messageTimer > 0 then
        if editorButtons.export.exportMessage:find("Exported") then
            love.graphics.setColor(0, 1, 0, 1) -- Green for success
        else
            love.graphics.setColor(1, 0, 0, 1) -- Red for failure
        end
        love.graphics.print(editorButtons.export.exportMessage,
            editorButtons.export.x,
            editorButtons.export.y + editorButtons.export.height + 5)
    end

    -- Draw level name
    love.graphics.setColor(colors.title)
    love.graphics.print("Editing: " .. selectedLevel, 200, 20)

    -- Draw the map grid
    if currentMap and #currentMap > 0 then
        for y = 1, #currentMap do
            for x = 1, #currentMap[y] do
                local tileX = 200 + (x - 1) * tileSize
                local tileY = 50 + (y - 1) * tileSize

                -- Draw tile
                if currentMap[y][x] == 0 then
                    love.graphics.setColor(colors.path)
                else
                    love.graphics.setColor(colors.grass)
                end

                love.graphics.rectangle("fill", tileX, tileY, tileSize, tileSize)

                -- Draw grid lines
                love.graphics.setColor(colors.grid)
                love.graphics.rectangle("line", tileX, tileY, tileSize, tileSize)
            end
        end
    end
end

function drawCreateLevel()
    -- Implement the UI for creating a new level
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Enter level name:", 100, 80)
    love.graphics.print("Enter level description:", 100, 160)

    -- Draw input fields
    if editingField == "name" then
        love.graphics.setColor(0.3, 0.7, 1, 1) -- Highlight active field
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
    end
    love.graphics.rectangle("fill", 100, 110, 300, 30)

    if editingField == "description" then
        love.graphics.setColor(0.3, 0.7, 1, 1) -- Highlight active field
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
    end
    love.graphics.rectangle("fill", 100, 190, 300, 30)

    -- Draw text in input fields
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(newLevelName, 105, 115)
    love.graphics.print(newLevelDescription, 105, 195)

    -- Draw buttons
    love.graphics.setColor(colors.buttonNormal)
    love.graphics.rectangle("fill", 100, 240, 150, 40) -- Create button

    love.graphics.rectangle("fill", 260, 240, 150, 40) -- Cancel button

    love.graphics.setColor(colors.buttonText)
    love.graphics.print("Create Level", 115, 250)
    love.graphics.print("Cancel", 305, 250)
end

function love.textinput(text)
    if gameState == "editor" and editorState == "createLevel" then
        if editingField == "name" then
            newLevelName = newLevelName .. text
        elseif editingField == "description" then
            newLevelDescription = newLevelDescription .. text
        end
    end
end

function love.keypressed(key)
    if gameState == "menu" then
        if key == "up" then
            selectedButton = selectedButton - 1
            if selectedButton < 1 then selectedButton = #buttons end
        elseif key == "down" then
            selectedButton = selectedButton + 1
            if selectedButton > #buttons then selectedButton = 1 end
        elseif key == "return" or key == "space" then
            buttons[selectedButton].action()
        end
    elseif gameState == "editor" and editorState == "createLevel" then
        if key == "return" or key == "tab" then
            if editingField == "name" then
                editingField = "description"
            elseif editingField == "description" then
                editingField = "name"
            end
        elseif key == "backspace" then
            if editingField == "name" then
                newLevelName = newLevelName:sub(1, -2)
            elseif editingField == "description" then
                newLevelDescription = newLevelDescription:sub(1, -2)
            end
        elseif key == "escape" then
            editorState = "selectLevel"
        end
    end
end

function love.mousemoved(x, y)
    if gameState == "menu" then
        local centerX = love.graphics.getWidth() / 2
        local centerY = love.graphics.getHeight() / 2

        for i, button in ipairs(buttons) do
            local buttonWidth = 200
            local buttonHeight = 50
            local buttonX = centerX - buttonWidth / 2
            local buttonY = centerY - 50 + (i - 1) * 70

            if x > buttonX and x < buttonX + buttonWidth and
                y > buttonY and y < buttonY + buttonHeight then
                selectedButton = i
                break
            end
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Left click
        if gameState == "menu" then
            local centerX = love.graphics.getWidth() / 2
            local centerY = love.graphics.getHeight() / 2

            for i, menuButton in ipairs(buttons) do
                local buttonWidth = 200
                local buttonHeight = 50
                local buttonX = centerX - buttonWidth / 2
                local buttonY = centerY - 50 + (i - 1) * 70

                if x > buttonX and x < buttonX + buttonWidth and
                    y > buttonY and y < buttonY + buttonHeight then
                    menuButton.action()
                    break
                end
            end
        elseif gameState == "editor" then
            if editorState == "selectLevel" then
                -- Handle back button click
                if x >= editorButtons.back.x and x <= editorButtons.back.x + editorButtons.back.width and
                    y >= editorButtons.back.y and y <= editorButtons.back.y + editorButtons.back.height then
                    editorButtons.back.action()
                end

                -- Check if new level button was clicked
                if x >= editorButtons.newLevel.x and x <= editorButtons.newLevel.x + editorButtons.newLevel.width and
                    y >= editorButtons.newLevel.y and y <= editorButtons.newLevel.y + editorButtons.newLevel.height then
                    editorButtons.newLevel.action()
                    return
                end

                -- Handle level selection
                for i, levelFile in ipairs(levels) do
                    local levelY = 120 + (i - 1) * 40
                    if x > 100 and x < 400 and y > levelY and y < levelY + 30 then
                        if loadLevel(levelFile) then
                            editorState = "editMap"
                        end
                        break
                    end
                end
            elseif editorState == "editMap" then
                -- Handle editor tool buttons
                for _, button in pairs(editorButtons) do
                    if x >= button.x and x <= button.x + button.width and
                        y >= button.y and y <= button.y + button.height then
                        button.action()
                        break
                    end
                end

                -- Handle map clicks
                if currentMap and #currentMap > 0 then
                    for mapY = 1, #currentMap do
                        for mapX = 1, #currentMap[mapY] do
                            local tileX = 200 + (mapX - 1) * tileSize
                            local tileY = 50 + (mapY - 1) * tileSize

                            if x >= tileX and x < tileX + tileSize and
                                y >= tileY and y < tileY + tileSize then
                                -- Set tile type based on selected tool
                                if editorTool == "path" then
                                    currentMap[mapY][mapX] = 0
                                elseif editorTool == "grass" then
                                    currentMap[mapY][mapX] = 1
                                end
                                isMouseDown = true
                            end
                        end
                    end
                end
            elseif editorState == "createLevel" then
                -- Handle input field selection
                if x >= 100 and x <= 400 and y >= 110 and y <= 140 then
                    editingField = "name"
                elseif x >= 100 and x <= 400 and y >= 190 and y <= 220 then
                    editingField = "description"
                end

                -- Handle Create button click
                if x >= 100 and x <= 250 and y >= 240 and y <= 280 then
                    if newLevelName:len() > 0 then
                        -- Create the new level
                        if createNewLevel(newLevelName, newLevelDescription) then
                            editorState = "editMap"
                        end
                    end
                end

                -- Handle Cancel button click
                if x >= 260 and x <= 410 and y >= 240 and y <= 280 then
                    editorState = "selectLevel"
                end
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then -- Left click
        isMouseDown = false
    end
end
