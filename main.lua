function love.load()
    loveframes = require("LoveFrames")
    msg = require("msg")
end

once = true

function love.update(dt)
    if once then
        msg.connect("127.0.0.1:32501")
        once = false
        print('done')
    end

    msg.update(dt)
    loveframes.update(dt)
end

function love.mousepressed(x, y, button)
    loveframes.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    loveframes.mousereleased(x, y, button)
end

function love.keypressed(key, unicode)
    loveframes.keypressed(key, unicode)
end

function love.keyreleased(key, unicode)
    loveframes.keyreleased(key, unicode)
end

function love.textinput(text)
    loveframes.textinput(text)
end

