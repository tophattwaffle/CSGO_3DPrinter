fileList <- []
//fileList <- ["csgobenchy.gcode","fred.gcode","90deg.gcode","gradientest.gcode"]
fileListEnts <- []

fileListPosition <- Entities.FindByName(null, "@fileList")
fileListVerticalOffset <- 24
fileListIdleColor <- "160 160 255"
fileListHoverColor <- "240 240 128"
fileListselectedColor <- "70 255 70"
bCanSelectFile <- false
currentHoveredFile <- null
selectedFile <- null
selectedFileIndex <- -1
bIsPrinting <- false

::HandleIncomingFiles <- function(msg)
{
    printl("Added: " + msg)
    fileList.append(msg + ".gcode")
    DrawFileList()
}.bindenv(this)

function StartPrint()
{
    if(bIsPrinting)
    {    
        ScriptPrintMessageCenterAll("Already printing!")
        return
    }

    if(selectedFile == null)
    {    
        ScriptPrintMessageCenterAll("Select a file first!")
        return
    }

    local cmd = "[OCTO]start_" + selectedFileIndex
    EntFireByHandle(masterScript, "RunScriptCode", "printSolo(\"" + cmd + "\")" , 0.5, null, null)
    EntFireByHandle(statusText, "addoutput", "message Printing!", 0.00, null, null)
    EntFireByHandle(statusText, "addoutput", "color 128 128 255", 0.00, null, null)
    EntFire("killMe","kill")
    IsPrinting = true
}

function UpdateFileList()
{
    printl("Updating file list!")
    
    //TEMP DISABLED FOR TESTING
    EntFireByHandle(masterScript, "RunScriptCode", "printSolo(\"[OCTO]updateFiles\")", 0.5, null, null)
    fileList = []
    //force a draw for testing purposes
    //DrawFileList()
}

function DrawFileList()
{
    printl("PRINTING FILES")
    local fileListcounter = 0
    fileListEnts = []
    foreach(s in fileList)
    {
        local text = "[]"+s
        local ent = CreateWorldText(fileListPosition.GetOrigin(),fileListPosition.GetAngles(),16,fileListIdleColor,text,"file_" + fileListcounter,fileListVerticalOffset * fileListcounter)
        fileListcounter++
        fileListEnts.append(ent)
    }
    bCanSelectFile = true
    EntFireByHandle(masterScript, "RunScriptCode", "HandleFileSelection()", 0.00, null, null)
}

::playerShoot <- function()
{
    if(bCanSelectFile && currentHoveredFile != null)
    {
        selectedFile = currentHoveredFile
        ScriptPrintMessageCenterAll("Selected: " + GetStringOfSelectedFile())
    }    

}.bindenv(this)

function GetStringOfSelectedFile()
{
    local foundIndex = -1
    for(local i = 0; i < fileList.len(); i++)
    {
        if(fileListEnts[i] == selectedFile)
        {
            foundIndex = i
            break
        }
    }

    selectedFileIndex = foundIndex

    if(foundIndex == -1)
        return null

    return fileList[foundIndex]
}

function HandleFileSelection()
{
    if(bIsPrinting)
        return

    if(HPlayer == null && !bCanSelectFile)
        return

	local bLooking
	local eyePos = HPlayer.EyePosition()

    EntFire("file_*", "addoutput", "color " + fileListIdleColor, 0.00)

    if(selectedFile != null)
        EntFireByHandle(selectedFile, "addoutput", "color " + fileListselectedColor, 0.00, null, null)

    foreach(t in fileListEnts)
    {
        
        local targetVector = t.GetOrigin()
        targetVector = Vector(targetVector.x,targetVector.y,targetVector.z + (fileListVerticalOffset / 4))
        // only check if there is direct LOS with the target
	    if ( !VS.TraceLine( eyePos, targetVector ).DidHit() )
	    {
		    bLooking = VS.IsLookingAt( eyePos, targetVector, extendedHPlayer.EyeForward(), 0.999 )
            if(bLooking)
            {
                EntFireByHandle(t, "addoutput", "color " + fileListHoverColor, 0.00, null, null)
                currentHoveredFile = t
                break
            }
	    }

        currentHoveredFile = null
    }

    EntFireByHandle(masterScript, "RunScriptCode", "HandleFileSelection()", 0.10, null, null)
}

function CreateWorldText(position,angles,textsize,color,message,targetname,vertOffset)
{
    worldText <- Entities.CreateByClassname("point_worldtext");
    EntFireByHandle(worldText, "AddOutput", "targetname " + targetname, 0, null, null);
    worldText.SetOrigin(Vector(position.x, position.y,position.z + vertOffset))
    worldText.SetAngles(angles.x, angles.y, angles.z)
    worldText.__KeyValueFromString("color", color)
    worldText.__KeyValueFromString("message", message)
    worldText.__KeyValueFromFloat("size", textsize)
    return worldText
}