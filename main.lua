-- Goblin Blasters
-- Tower Defense Game

-- Import JSON library
local json = require("vendor.json.json")
-- Import LevelEditor class
local LevelEditor = require("src.LevelEditor")
-- Import LevelSelect class
local LevelSelect = require("src.LevelSelect")
-- Import Game class
local Game = require("src.Game")

-- Menu state management
local gameState = "menu"
local buttons = {}
local selectedButton = 1

-- Level editor instance
local levelEditor = nil
-- Level select instance
local levelSelect = nil
-- Game instance
local game = nil
-- Current level path
local currentLevel = nil

-- Colors
local colors = {
    background = { 0.1, 0.1, 0.3, 1 },
    title = { 0.9, 0.7, 0.2, 1 },
    buttonNormal = { 0.2, 0.4, 0.8, 1 },
    buttonHover = { 0.3, 0.5, 0.9, 1 },
    buttonText = { 1, 1, 1, 1 }
}

function love.load()
    -- Set up fonts
    titleFont = love.graphics.newFont(48)
    menuFont = love.graphics.newFont(24)

    -- Create buttons
    buttons = {
        { text = "Start Game", action = function() 
            gameState = "level_select" 
            -- Create level select instance if it doesn't exist
            if not levelSelect then
                levelSelect = LevelSelect.new()
            end
        end },
        { text = "Load Game",  action = function() gameState = "load" end },
        {
            text = "Level Creator",
            action = function()
                gameState = "editor"
                -- Create level editor instance if it doesn't exist
                if not levelEditor then
                    levelEditor = LevelEditor.new()
                end
            end
        },
        { text = "Exit", action = function() love.event.quit() end }
    }

    -- Text input handlers
    love.keyboard.setKeyRepeat(true)
end

function love.update(dt)
    if gameState == "menu" then
        -- Menu logic here
    elseif gameState == "level_select" then
        -- Update level select screen
        levelSelect:update(dt)
    elseif gameState == "game" then
        -- Game logic will go here
        if game then
            game:update(dt)
        end
    elseif gameState == "load" then
        -- Load game logic will go here
    elseif gameState == "editor" then
        -- Update level editor
        levelEditor:update(dt)
    end
end

function love.draw()
    -- Set background
    love.graphics.setBackgroundColor(colors.background)

    if gameState == "menu" then
        drawMenu()
    elseif gameState == "level_select" then
        levelSelect:draw()
    elseif gameState == "game" then
        if game then
            game:draw()
        else
            -- Fallback if game not initialized
            love.graphics.print("Game screen - not initialized", 100, 100)
            love.graphics.print("Level: " .. (currentLevel or "None"), 100, 130)
        end
    elseif gameState == "load" then
        love.graphics.print("Load game screen - not implemented yet", 100, 100)
    elseif gameState == "editor" then
        levelEditor:draw()
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

function love.textinput(text)
    if gameState == "editor" then
        levelEditor:textinput(text)
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
    elseif gameState == "editor" then
        levelEditor:keypressed(key)
    elseif gameState == "game" then
        -- Handle back to menu on escape
        if key == "escape" then
            gameState = "menu"
            game = nil
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
        elseif gameState == "level_select" then
            -- Forward mouse press to level select
            local result, levelPath = levelSelect:mousepressed(x, y, button)
            -- Check if level select wants us to change game state
            if result then
                if result == "play_level" and levelPath then
                    currentLevel = levelPath
                    gameState = "game"
                    -- Initialize game with selected level
                    game = Game.new(currentLevel)
                else
                    gameState = result
                end
            end
        elseif gameState == "editor" then
            -- Forward mouse press to level editor
            local result = levelEditor:mousepressed(x, y, button)
            -- Check if editor wants us to change game state
            if result then
                gameState = result
            end
        elseif gameState == "game" and game then
            -- Forward mouse press to game
            local result = game:mousepressed(x, y, button)
            -- Handle any game state changes
            if result then
                if result == "menu" then
                    gameState = "menu"
                    game = nil
                elseif result == "start_game" then
                    -- This is where actual gameplay would start
                    -- For now we'll just stay in the same state
                    print("Starting game with level: " .. (currentLevel or "unknown"))
                end
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then -- Left click
        if gameState == "editor" then
            levelEditor:mousereleased(x, y, button)
        end
    end
end
