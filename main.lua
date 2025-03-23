-- Goblin Blasters
-- Tower Defense Game

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

-- Colors
local colors = {
    background = {0.1, 0.1, 0.3, 1},
    title = {0.9, 0.7, 0.2, 1},
    buttonNormal = {0.2, 0.4, 0.8, 1},
    buttonHover = {0.3, 0.5, 0.9, 1},
    buttonText = {1, 1, 1, 1},
    path = {0.8, 0.7, 0.5, 1},
    grass = {0.3, 0.8, 0.3, 1},
    grid = {0.5, 0.5, 0.5, 0.3},
    toolSelected = {1, 1, 0, 1}
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
        -- Use Lua string pattern matching to parse the JSON
        local levelData = {}
        
        -- Extract map data using pattern matching
        levelData.map = {}
        for mapRow in content:gmatch('"([01]+)"') do
            table.insert(levelData.map, mapRow)
        end
        
        if #levelData.map > 0 then
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
    
    local content = love.filesystem.read("levels/" .. selectedLevel)
    if not content then return false end
    
    -- Create map strings in JSON format (array of strings)
    local mapStrings = {}
    for i, row in ipairs(currentMap) do
        local rowStr = ""
        for j, tile in ipairs(row) do
            rowStr = rowStr .. tostring(tile)
        end
        table.insert(mapStrings, '"' .. rowStr .. '"')
    end
    
    -- Format map strings as JSON array
    local mapJsonArray = "[\n      " .. table.concat(mapStrings, ",\n      ") .. "\n    ]"
    
    -- Find the map section in the file and replace it
    -- Use a simpler pattern that matches the map array with proper handling of newlines and spaces
    local startPattern = '"map":%s*%['
    local endPattern = '%s*%]'
    
    -- Find the start of the map section
    local startPos = content:find(startPattern)
    if not startPos then
        return false
    end
    
    -- Find the end bracket of the map array
    local searchPos = startPos
    local bracketCount = 0
    local endPos = nil
    
    -- Skip to the opening bracket
    searchPos = content:find('%[', searchPos)
    bracketCount = 1
    
    -- Search for the matching closing bracket
    while bracketCount > 0 and searchPos do
        searchPos = searchPos + 1
        if searchPos > #content then
            return false
        end
        
        local char = content:sub(searchPos, searchPos)
        if char == "[" then
            bracketCount = bracketCount + 1
        elseif char == "]" then
            bracketCount = bracketCount - 1
            if bracketCount == 0 then
                endPos = searchPos
            end
        end
    end
    
    if not endPos then
        return false
    end
    
    -- Build the new content with the updated map
    local beforeMap = content:sub(1, startPos + 5) -- +5 to include the "map": part
    local afterMap = content:sub(endPos)
    local newContent = beforeMap .. mapJsonArray .. afterMap
    
    -- Write the updated content back to file
    return love.filesystem.write("levels/" .. selectedLevel, newContent)
end

function love.load()
    -- Set up fonts
    titleFont = love.graphics.newFont(48)
    menuFont = love.graphics.newFont(24)
    editorFont = love.graphics.newFont(18)
    
    -- Create buttons
    buttons = {
        {text = "Start Game", action = function() gameState = "game" end},
        {text = "Load Game", action = function() gameState = "load" end},
        {text = "Level Creator", action = function() 
            gameState = "editor" 
            editorState = "selectLevel"
            loadLevelsList()
        end},
        {text = "Exit", action = function() love.event.quit() end}
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
                    editorButtons.save.saveMessage = "Saved successfully!"
                    editorButtons.save.messageTimer = 3 -- Show for 3 seconds
                else
                    editorButtons.save.saveMessage = "Failed to save!"
                    editorButtons.save.messageTimer = 3
                end
            end
        }
    }
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
        if editorButtons.save.saveMessage:find("Success") then
            love.graphics.setColor(0, 1, 0, 1) -- Green for success
        else
            love.graphics.setColor(1, 0, 0, 1) -- Red for failure
        end
        love.graphics.print(editorButtons.save.saveMessage, 
                           editorButtons.save.x, 
                           editorButtons.save.y + editorButtons.save.height + 5)
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
                -- Check if clicked on a level
                for i, levelFile in ipairs(levels) do
                    local buttonY = 120 + (i - 1) * 40
                    if x >= 100 and x <= 400 and y >= buttonY and y <= buttonY + 30 then
                        if loadLevel(levelFile) then
                            editorState = "editMap"
                        end
                        break
                    end
                end
                
                -- Check if clicked back button
                if x >= editorButtons.back.x and x <= editorButtons.back.x + editorButtons.back.width and
                   y >= editorButtons.back.y and y <= editorButtons.back.y + editorButtons.back.height then
                    editorButtons.back.action()
                end
            elseif editorState == "editMap" then
                -- Check if clicked on any editor buttons
                for _, button in pairs(editorButtons) do
                    if x >= button.x and x <= button.x + button.width and
                       y >= button.y and y <= button.y + button.height then
                        button.action()
                        return -- Return to avoid setting isMouseDown
                    end
                end
                
                -- If clicked on map area, set isMouseDown for drawing
                if x > 200 and y > 50 then
                    isMouseDown = true
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
