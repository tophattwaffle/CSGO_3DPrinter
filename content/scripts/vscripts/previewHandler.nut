lineLifeTime <- 999 * 60
currentZ <- 0
lineColorR <- 96
lineColorG <- 192
lineColorB <- 192
colorChangeAmount <- 0
lastColorChangeAmount <- 0
linesDrawn <- 0
gradientDirection <- true
currentZText <- Entities.FindByName(null, "@currentZ")


//Store a location history. Used for drawing
locationHistory <- [null,null,null]

function handleColorChange(input)
{
    colorChangeAmount = FindAngleBetweenLinesFromFixed(input,locationHistory[0])
    
    if(colorChangeAmount > 0)
        colorChangeAmount += 90

    colorChangeAmount = abs(colorChangeAmount)

    //printl(colorChangeAmount)

    /*
    lastColorChangeAmount = colorChangeAmount
    //This is the "preset" color change code. The new code has a nice shading on the item
    local diff = FindAngleBetweenLines(input,locationHistory[0],locationHistory[1])
    if(lastColorChangeAmount == 0)
    {
        if(diff > 75)
            colorChangeAmount = 128
        else if(diff > 35)
            colorChangeAmount = 64
        
        lastColorChangeAmount = colorChangeAmount
    }
    else
        lastColorChangeAmount = 0
    */

    //lineColorR -= colorChangeAmount
    lineColorG -= colorChangeAmount
    lineColorB -= colorChangeAmount
}

function ResetColorChange()
{
    if(colorChangeAmount == 0)
        return

    //lineColorR += colorChangeAmount
    lineColorG += colorChangeAmount
    lineColorB += colorChangeAmount

    colorChangeAmount = 0
}

function HandleG1(input)
{
    local parsed = ParseG1(input)

    //Only draw valid moves
    if(parsed.z == 1 && parsed.x != -1 && parsed.y != -1)
    {
        handleColorChange(parsed)
        DrawMove(parsed)
        ResetColorChange()
    }

    //Make sure to store the last location so we know where to draw from next.
    //But we must be sure that we don't store invalid items
    if(parsed.x != -1 && parsed.y != -1)
    {
        locationHistory.insert(0,parsed)
        locationHistory.pop()
    }
}

function DrawMove(nextPoint)
{
    linesDrawn++
    local startingPoint = Vector(nextPoint.x + home.x, nextPoint.y + home.y, currentZ + home.z)
    local endPoint = Vector(locationHistory[0].x + home.x, locationHistory[0].y + home.y, currentZ + home.z)
    DebugDrawLine(startingPoint, endPoint, lineColorR,lineColorG,lineColorB, false, lineLifeTime)
    VS.DrawVertArrow(Vector(startingPoint.x,startingPoint.y,startingPoint.z+32),Vector(startingPoint.x, startingPoint.y, startingPoint.z + 1), 2, 255,0,0,false,0.05)
}

function ParseG1(input)
{
    local arr = split(input," ")
    local newVector = Vector(-1,-1,-1)
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
                EntFireByHandle(currentZText, "addoutput", "message Current Z - " + currentZ, 0.00, null, null)

                //Flip between 255 and 96
                if(lineColorR >= 255 || lineColorR < 96)
                    gradientDirection = !gradientDirection

                //This gives us a nice gradient was we move upwards
                if(gradientDirection)
                    lineColorR = lineColorR += 1
                else
                    lineColorR = lineColorR -= 1

                break
            case "E":
                if(a.find("-"))//Filter out moves that are of negative values
                    break

                newVector.z = 1 //1 means we are a valid
                break
            default:
                continue
                break
        }
    }
    return newVector
}