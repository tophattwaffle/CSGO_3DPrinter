lastLocation <- null
currentZ <- 0
lineColorR <- 0
lineColorG <- 255
lineColorB <- 0

function handleColor()
{
        lineColorR = (lineColorR <= 255 ? lineColorR += 2 : lineColorR = 0)
        lineColorG = (lineColorG >= 0 ? lineColorG -= 2 : lineColorG = 255)
        lineColorB = (lineColorB <= 255 ? lineColorB += 1 : lineColorB = 0)
}

function HandleG1(input)
{
    local parsed = ParseG1(input)

    //Not a valid move
    if(parsed == null)
        return

    if(lastLocation == null)
    {   
        lastLocation = parsed
        return
    }

    handleColor()
    DrawMove(parsed)
}

function DrawMove(nextPoint)
{
    local startingPoint = Vector(nextPoint.x + home.x, nextPoint.y + home.y, currentZ + 10)
    local endPoint = Vector(lastLocation.x + home.x, lastLocation.y + home.y, currentZ + 10)
    DebugDrawLine(startingPoint, endPoint, lineColorR,lineColorG,lineColorB, false, 480)
    lastLocation = nextPoint
}

function ParseG1(input)
{
    local arr = split(input," ")
    local newVector = Vector(-1,-1,0)

    foreach (a in arr)
    {   
        switch(a.slice(0,1))
        {
            case "X":
                newVector.x = a.slice(1).tofloat()
                break
            case "Y":
                newVector.y = a.slice(1).tofloat()
                break
            case "Z":
                currentZ = a.slice(1).tofloat()
                break
            case "E":
                if(a.find("-"))
                    break

                newVector.z = -1 //-1 means we are a valid
                break
            default:
                continue
                break
        }
    }
    if(newVector.z == -1 && newVector.x != -1 && newVector.y != -1)
        return newVector
    
    return null
}