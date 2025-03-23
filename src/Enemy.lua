-- Enemy Class
local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(waypoints, enemyType)
    local self = setmetatable({}, Enemy)

    -- Enemy properties
    self.waypoints = waypoints or {}
    self.type = enemyType or "basic"
    self.currentWaypoint = 1
    self.position = {
        x = waypoints[1] and waypoints[1].x or 0,
        y = waypoints[1] and waypoints[1].y or 0
    }

    -- Enemy stats based on type
    if self.type == "basic" then
        self.health = 100
        self.speed = 30                   -- pixels per second
        self.color = { 0.2, 0.2, 0.8, 1 } -- Blue
        self.size = 20
    elseif self.type == "fast" then
        self.health = 60
        self.speed = 60                   -- pixels per second
        self.color = { 0.8, 0.2, 0.2, 1 } -- Red
        self.size = 15
    else
        -- Default values
        self.health = 100
        self.speed = 30
        self.color = { 0.5, 0.5, 0.5, 1 } -- Gray
        self.size = 20
    end

    self.isDead = false
    self.reachedEnd = false

    return self
end

function Enemy:update(dt)
    if self.isDead or self.reachedEnd then return end

    -- Check if we have waypoints to follow
    if #self.waypoints < 2 or self.currentWaypoint >= #self.waypoints then
        self.reachedEnd = true
        return
    end

    -- Get current and next waypoint
    local current = self.waypoints[self.currentWaypoint]
    local next = self.waypoints[self.currentWaypoint + 1]

    -- Calculate direction vector
    local dx = next.x - current.x
    local dy = next.y - current.y
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Normalize direction
    if distance > 0 then
        dx = dx / distance
        dy = dy / distance
    end

    -- Move toward next waypoint
    local moveDistance = self.speed * dt
    local newX = self.position.x + dx * moveDistance
    local newY = self.position.y + dy * moveDistance

    -- Check if we've reached or passed the next waypoint
    local reachedNextWaypoint = false

    -- Check if we've moved past the next waypoint
    if dx > 0 and newX >= next.x or
        dx < 0 and newX <= next.x or
        dx == 0 and
        (dy > 0 and newY >= next.y or
            dy < 0 and newY <= next.y) then
        reachedNextWaypoint = true
    end

    if reachedNextWaypoint then
        -- Move to the next waypoint
        self.currentWaypoint = self.currentWaypoint + 1
        self.position.x = next.x
        self.position.y = next.y
    else
        -- Update position
        self.position.x = newX
        self.position.y = newY
    end
end

function Enemy:draw(offsetX, offsetY, tileSize)
    if self.isDead then return end

    love.graphics.setColor(unpack(self.color))

    local x = offsetX + self.position.x * tileSize + tileSize / 2
    local y = offsetY + self.position.y * tileSize + tileSize / 2

    -- Draw enemy
    love.graphics.circle("fill", x, y, self.size / 2)

    -- Draw health bar
    local healthBarWidth = tileSize * 0.8
    local healthBarHeight = 5
    local healthPercentage = self.health / 100

    -- Background
    love.graphics.setColor(0.3, 0.3, 0.3, 0.7)
    love.graphics.rectangle("fill",
        x - healthBarWidth / 2,
        y - self.size / 2 - 10,
        healthBarWidth,
        healthBarHeight)

    -- Health fill
    love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
    love.graphics.rectangle("fill",
        x - healthBarWidth / 2,
        y - self.size / 2 - 10,
        healthBarWidth * healthPercentage,
        healthBarHeight)
end

function Enemy:takeDamage(amount)
    self.health = self.health - amount
    if self.health <= 0 then
        self.isDead = true
    end
end

return Enemy
