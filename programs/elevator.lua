--$ARGS|Channel (10)|Floor Number (1)|Floor Name (Unnamed)|Elevator at floor Redstone Intput (bottom white)|Is floor destination Redstone Output (bottom red)|Direction Redstone Output (bottom green)|Moving Redstone Output (bottom blue)|Is Host (false)|$ARGS

-- Args
local args = { ... }
local channel = tonumber(args[1]) or 10
local floorNum = tonumber(args[2]) or 1
local floorName = args[3] or "Unnamed"
local elevatorAtDestinationRedstoneInput = args[4] or "bottom white"
local destinationRedstoneOutput = args[5] or "bottom red"
local directionRedstoneOutput = args[6] or "bottom green"
local movingRedstoneOutput = args[7] or "bottom blue"
local isHost = args[8] == "true"

-- Libraries
local setup = require("/lua/lib/setupUtils")
local monUtils = require("/lua/lib/monitorUtils")
local write = monUtils.write
local drawBox = monUtils.drawBox
local stateHandler = require("/lua/lib/stateHandler")
local network = require("/lua/lib/networkUtils")
local utils = require("/lua/lib/utils")

-- Peripherals
local wrappedPers = setup.getPers({
    "monitor",
    "modem"
})
local monitor = setup.setupMonitor(
    wrappedPers.monitor[1], 0.5
)
local modem = wrappedPers.modem[1]
local speaker = peripheral.find("speaker")

-- Setup
local floors = {}
local moving = false
local direction = 0

local stateData = stateHandler.getState("elevator")
local defaultData = 1
local currentFloorIndex = stateData or defaultData

local destionationFloor = currentFloorIndex;
local betweenFloors = [];

-- Windows
local winHeader = setup.setupWindow(
    monitor, 1, 1, monitor.x, 6
)
local winFooter = setup.setupWindow(
    monitor, 1, (monitor.y - 3), monitor.x, 4
)
local winMain = setup.setupWindow(
    monitor, 1, 7, monitor.x, (monitor.y - (6 + 4)) 
)

-- Main
function start()
    print("# Program Started")
    
    local deviceData = {
        floorNum = floorNum,
        floorName = floorName
    }

    floor = { deviceData }

    local joinOrCreate = function()
        network.joinOrCreate(channel, isHost, deviceData,
            function(devices)
                floors = utils.filterTable(devices, function(device, newDevices)
                    for _,newDevice in ipairs(newDevices) do
                        if newDevice.floorNum == device.floorNum then return false end
                    end
                    return true
                end)
                table.sort(floors,
                    function(a, b) return a.floorNum > b.floorNum end
                )
                drawHeader()
                drawFooter()
                drawMain()
            end
        )
    end

    parallel.waitForAny(joinOrCreate, awaitFloorSelection)
end

function awaitFloorSelection()
    while(true) do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isTouch = (event == "monitor_touch")
        
        local isModemMessage = (event == "modem_message")
        
        if(isTouch) then
            local x = p2
            local y = p3 - winHeader.y
            
            local floorIndex = y - 4
            local floor = floors[floorIndex]
            if(floor and (floorIndex) ~= currentFloorIndex) then
                modem.transmit(channel, channel,
                    {
                        type = "floorSelected",
                        floorIndex = floorIndex
                    }
                )
                moveTo(floorIndex)
                break
            end
        elseif(isModemMessage) then
            local body = p4
            if(body.type == "floorSelected") then
                moveTo(body.floorIndex)
                break
            end
        end
    end
end

function moveTo(floorIndex)
    local floor = floors[floorIndex]
    direction = currentFloorIndex - floorIndex 
    destionationFloor = currentFloorIndex = floorIndex
    moving = true
    updateState()
    
    if(speaker) then
        speaker.playSound(
            "minecraft:entity.experience_orb.pickup",
            1, 0.5
        )
    end
    
    setRedstoneSignal(floor.floorNum)
    
    drawMain()
    parallel.waitForAny(
        drawMoving,
        awaitElevatorAtDestionation,
        function() sleep(120) end
    )
    moving = false
    drawMain()
    
    setRedstoneSignal(floor.floorNum)
    
    if(speaker) then
        speaker.playSound(
            "minecraft:entity.player.levelup",
            1, 0.5
        )
    end
    
    awaitFloorSelection()
end

function split(str, sep, plain)
    if plain then sep = string.gsub(sep, magic, "%%%1") end
    
    local N = '\255'
    str = N..str..N
    str = string.gsub(str, sep, N..N)

    local result = {}
    for word in string.gmatch(str, N.."(.-)"..N) do
        if word ~= "" then
            table.insert(result, word)
        end
    end
    return result
end

function setRedstoneFor(sideAndColor, output)
    local side, color = split(sideAndColor, ' ');
    if color then
        local combinedColors = redstone.getBundledOutput(side);
        if output then
            combinedColors = colors.combine(combinedColors, colors[color]);
        else
            combinedColors = colors.substract(combinedColors, colors[color]);
        end
        redstone.setBundledOutput(side, output);
    else
        redstone.setOutput(side, output);
    end
end

function getRedstoneFor(sideAndColor, output)
    local side, color = split(sideAndColor, ' ');
    if color then
        return colors.test(redstone.getBundledOutput(side), colors[color]);
    else
        return redstone.getOutput(side);
    end
end

function setRedstoneSignal(targetFloorNum)
    -- is not destination floor
    setRedstoneFor(destinationRedstoneOutput, floorNum ~= targetFloorNum);

    if(isHost) then
        -- gearshift
        setRedstoneFor(directionRedstoneOutput, direction < 0);
        -- clutch
        setRedstoneFor(movingRedstoneOutput, moving == false);
    end
end

function updateState()
    stateHandler.updateState("elevator", currentFloorIndex)
end

function drawHeader()
    winHeader.bg = colors.blue
    winHeader.setBackgroundColor(winHeader.bg)
    
    drawBox(winHeader,
        1, 1, winHeader.x, winHeader.y,
        true
    )
    drawBox(winHeader,
        1, winHeader.y, winHeader.x, winHeader.y,
        true, colors.white
    )
    
    write(winHeader, "Elevator", 0, 2, "center")
    write(winHeader, "This Floor: " .. floorName, 0, 4, "center")
end

function drawFooter()
    winFooter.bg = colors.blue
    winFooter.setBackgroundColor(winFooter.bg)
    
    drawBox(winFooter,
        1, 1, winFooter.x, winFooter.y,
        true
    )
    drawBox(winFooter,
        1, 1, winFooter.x, 1,
        true, colors.white
    )
    
    write(winFooter, "Select a floor", 2, 3, "left")
    write(winFooter, "Channel: " .. channel, 2, 3, "right" )
end

function drawMain()
    winMain.bg = colors.cyan
    winMain.setBackgroundColor(winMain.bg)
    
    drawBox(winMain,
        1, 1, winMain.x, winMain.y,
        true
    )
    
    if(moving == false) then
        drawFloors()
    end
end

function drawMoving()
    local i = 1
    local max = winMain.y - 4
    while(true) do
        i = i + 1
        if(i > max) then i = 1 end
        
        local dirStr = "v"
        if(direction > 0) then
            dirStr = "^"
        end
        
        winMain.clear()
        local floor = floors[currentFloorIndex]
        
        write(winMain,
            "Moving to: " .. floor.floorName,
            0, 2, "center"
        )
        
        for ii = 1, 5, 1 do
            local y = i + ii - 1
            if(y > max) then y = y % max end
            if(direction > 0) then
                y = (y - max - 1) * -1
            end
            
            write(winMain,
                dirStr,
                0, (y + 3), "center"
            )
        end
        
        os.sleep(0.1)
    end
end

function awaitElevatorAtDestionation()
    sleep(1)
    while(true) do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isRedstone = (event == "redstone")
        
        local isModemMessage = (event == "modem_message")
        
        if(isRedstone) then
            -- at floor or just left?
            local atFloor = getRedstoneFor(elevatorAtDestinationRedstoneInput);
            modem.transmit(channel, channel,
                {
                    type = "elevatorInFloor",
                    floorNum = floorNum,
                    atFloor = atFloor
                }
            )
            return
        elseif(isModemMessage) then
            local body = p4
            if(body.type == "elevatorInFloor") then
                if(body.floorNum == destionationFloor) then
                    return
                end

                -- 
            end
        end
        
    end
end
    
function drawFloors()
    if(currentFloorIndex > #floors) then 
        currentFloorIndex = 1
    end
    write(winMain,
        "Floor: " .. floors[currentFloorIndex].floorName,
        2, 2, "right"
    )
    write(winMain,
        "# Floors",
        2, 2, "left"
    )
    
    for i, floor in ipairs(floors) do
        local y = 4 + i
        if(i == currentFloorIndex) then
            drawBox(winMain,
                1, y, winMain.x, y,
                true, colors.blue
            )
            winMain.setBackgroundColor(colors.blue)
        end
        write(winMain,
            " > " .. floor.floorName .. " ",
            2, y, "left"
        )
        winMain.setBackgroundColor(winMain.bg)
    end
end

setup.utilsWrapper(start, modem, channel)