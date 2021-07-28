--$ARGS|Sync Server Channel|$ARGS

-- Args
local ARGS = { ... }
local CHANNEL = tonumber(ARGS[1]) or 40100

local PROGRAMS = {"program.lua"}
local DEPS = {"dep.lua"}

local function readInput(prefix)
    if prefix == nil then prefix = " ->" end
    print(prefix)
    _, y = term.getCursorPos()
    term.setCursorPos(#prefix + 2, y - 1)
    local input = read()
    print("")
    return input
end

local function printSettings()
    
    term.clear()
    print(" > Sync Client Settings\n")
    print(" - Programs")
    for _,program in ipairs(PROGRAMS) do
        print("  - "..program)
    end
    print(" - Dependencies")
    for _,dep in ipairs(DEPS) do

        print("  - "..dep)
    end
end

local function startInterface()
    local modem = peripheral.find("modem")
    if modem == nil then error("Could not start client, no modem present") end
    modem.open(CHANNEL)

    printSettings()

    readInput()

end

local function start()

    print(" > Starting Sync Client")

    startInterface();
  
end

start()