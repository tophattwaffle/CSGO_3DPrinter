//Nesest entries at index 0. Oldest at the end. 31 count, but we only ever display 30
toolTempHistory <- [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
bedTempHistory <- [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
tempGraphLocation <- Entities.FindByName(null, "@tempGraph")

graphSpacing <- 4
graphHeightFactor <- 0.25

function DrawGraphs()
{
    EntFireByHandle(masterScript, "RunScriptCode", "DrawGraphs()", 1, masterScript, masterScript)
    DrawGraph(toolTempHistory,255,0,0)
    DrawGraph(bedTempHistory,0,0,255)
}

//Starts draw from the bottom right (lmao what a choice) of the graph and draws backwards
function DrawGraph(arr,r,g,b)
{
    local graphOrigin = tempGraphLocation.GetOrigin()

    for (local i = 0;i < 30 ;i++ )
    {
        local startingPoint = Vector(graphOrigin.x - (graphSpacing * i), graphOrigin.y, graphOrigin.z + (arr[i].tofloat() * graphHeightFactor))
        local endingPoint = Vector(graphOrigin.x - (graphSpacing * (i+1)), graphOrigin.y, graphOrigin.z + (arr[i+1].tofloat() * graphHeightFactor))
        DebugDrawLine(startingPoint, endingPoint, r,g,b, false, 1.02)
    }

    for (local i = 0;i < 30 ;i++ )
    {
        local startingPoint = Vector(graphOrigin.x - 0.1 - (graphSpacing * i), graphOrigin.y, graphOrigin.z + 0.1 + (arr[i].tofloat() * graphHeightFactor))
        local endingPoint = Vector(graphOrigin.x - 0.1 - (graphSpacing * (i+1)), graphOrigin.y, graphOrigin.z + 0.1 + (arr[i+1].tofloat() * graphHeightFactor))
        DebugDrawLine(startingPoint, endingPoint, r,g,b, false, 1.02)
    }
    
}

function HandleTemps(input)
{
    local parsed = ParseTemps(input)
    UpdateTemps(parsed)
}

function ParseTemps(input)
{
    local split = split(input,":")
    
    //After a split we get each temp but with some extra stuff
    local tool = split[1]
    local bed = split[2]
    
    tool = tool.slice(0,tool.find("/"))
    bed = bed.slice(0,bed.find("/"))

    return [tool, bed]
}

function UpdateTemps(parsedTemps)
{
    toolTempHistory.insert(0,parsedTemps[0])
    toolTempHistory.pop()

    bedTempHistory.insert(0,parsedTemps[1])
    bedTempHistory.pop()
}