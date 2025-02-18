--$ARGS|Channel (30)|Redstone Output (right)|Name (Unnamed)|$ARGS

-- Args
local args = { ... }
local channel = tonumber(args[1]) or 30
local redstoneOutput = args[2] or "right"
local name = args[3] or "Unnamed"

-- Libraries
local setup = require("/lua/lib/setupUtils")
local monUtils = require("/lua/lib/monitorUtils")
local write = monUtils.write
local drawBox = monUtils.drawBox
local stateHandler = require("/lua/lib/stateHandler")

-- Peripherals
local wrappedPers = setup.getPers({
    "monitor", "modem"
})
local monitor = setup.setupMonitor(
    wrappedPers.monitor[1], 0.5
)
local modem = wrappedPers.modem[1]
local speaker = peripheral.find("speaker")

-- Setup
local stateData = stateHandler.getState("toggle")
local defaultData = "off"
local state = stateData or defaultData

-- Windows
local winHeader = setup.setupWindow(
    monitor, 1, 1, monitor.x, 4
)
local winFooter = setup.setupWindow(
    monitor, 1, 5, monitor.x, (monitor.y - 4)
)

-- Main
function start()
    print("# Program Started")
    modem.open(channel)
    
    drawHeader()
    drawFooter()
    
    await()
end

function await()
    while(true) do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isTouch = (event == "monitor_touch")
        
        local isModemMessage = (event == "modem_message")
        
        if(isTouch) then
            modem.transmit(channel, channel,
                { type = state }
            )
            if(state == "on") then
                off()
            elseif(state == "off") then
                on()
            end
        elseif(isModemMessage) then
            local body = p4
            if(body.type == "on") then
                off()
            elseif(body.type == "off") then
                on()
            end
        end
    end
end

function on()
    rs.setAnalogOutput(redstoneOutput, 15)
    if(speaker) then
        speaker.playSound(
            "minecraft:block.lever.click",
            1, 1
        )
    end
    state = "on"
    updateState()
    drawHeader()
    drawFooter()
end

function off()
    rs.setAnalogOutput(redstoneOutput, 0)
    if(speaker) then
        speaker.playSound(
            "minecraft:block.lever.click",
            1, 0.8
        )
    end
    state = "off"
    updateState()
    drawHeader()
    drawFooter()
end

function updateState()
    stateHandler.updateState("toggle", state)
end

function drawHeader()
    local bgColors = {
        on = colors.green,
        off = colors.red
    }
    winHeader.bg = bgColors[state]
    winHeader.setBackgroundColor(winHeader.bg)
    
    drawBox(winHeader,
        1, 1, winHeader.x, winHeader.y,
        true
    )
    drawBox(winHeader,
        1, winHeader.y, winHeader.x, winHeader.y,
        true, colors.white
    )
    
    write(winHeader, name, 0, 2, "center")
end

function drawFooter()
    local bgColors = {
        on = colors.green,
        off = colors.red
    }
    winFooter.bg = bgColors[state]
    winFooter.setBackgroundColor(winFooter.bg)
    
    drawBox(winFooter,
        1, 1, winFooter.x, winFooter.y,
        true
    )
    
    local msgs = {
        on = "Enabled",
        off = "Disabled"
    }
    
    write(winFooter,
        msgs[state],
        0, 2, "center"
    )
    
    write(winFooter,
        "Click to Toggle",
        0, (winFooter.y - 1), "center"
    )
end

setup.utilsWrapper(start, modem, channel)