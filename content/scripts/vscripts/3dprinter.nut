IncludeScript("vs_library")
IncludeScript("thw_util")
IncludeScript("tempHandler")
IncludeScript("previewHandler")
IncludeScript("fileHandler")

masterScript <- Entities.FindByName(null, "@masterScript")

latestSeenTempMessage <- null
homeEntity <- Entities.FindByName(null, "@home")
home <- null

HPlayer <- Entities.FindByClassname(null, "player")
extendedHPlayer <- ToExtendedPlayer(HPlayer)

commandHistory <- ["","","","","","","","","",""]
//CHANNEL THE SQUIDSKI CODE
commandHistoryText <- [Entities.FindByName(null, "@cmdHistory_1"),Entities.FindByName(null, "@cmdHistory_2"),Entities.FindByName(null, "@cmdHistory_3"),Entities.FindByName(null, "@cmdHistory_4"),Entities.FindByName(null, "@cmdHistory_5"),Entities.FindByName(null, "@cmdHistory_6"),Entities.FindByName(null, "@cmdHistory_7"),Entities.FindByName(null, "@cmdHistory_8"),Entities.FindByName(null, "@cmdHistory_9"),Entities.FindByName(null, "@cmdHistory_10")]
linesDrawnText <- Entities.FindByName(null, "@LinesDrawn")
statusText <- Entities.FindByName(null, "@status")
lastStatusUpdate <- ""
lastSequenceNumber <- 0

fragmentedMessage <- null

//Handles all incoming messages from the outside
::IncomingMessage <- function(msg)
{
    //printl(msg)

    if(StartsWith(msg,"T:") && msg.find("B:") != null)
    {
        HandleTemps(msg)
        return
    }

    /*
    All this code is redundant since we've resolve the issues with how SSH is reading octo...
    if(msg.find("*") == null)
    {
        fragmentedMessage = msg
        //printl("Possible Message Fragment Encountered: " + fragmentedMessage)
        return
    }
    else if(bIsPrinting)
    {
        if(fragmentedMessage != null)
        {
            msg = fragmentedMessage + msg
            //printl("Repaired fragmented message: " + msg)
            fragmentedMessage = null
        }
        
        msg = msg.slice(0,msg.find("*"))
    }

    //This code handles sequence number checking. This is important because sometimes
    //we may not get a G1 move, which results in a jump in line draws. Meaning we'd get the follow SEQs:
    //N322
    //N323
    //N325
    //We are missing N234 becuase we never got it from the SSH connection.

    local thisSequenceNum = GetSequenceNumber(msg)
    //printl("STR["+thisSequenceNum+"]")
    if(thisSequenceNum != null)
        thisSequenceNum = thisSequenceNum.tointeger()
    //printl("INT["+thisSequenceNum+"]")

    local sequenceGood = false

    //printl("thisSequenceNum:" + thisSequenceNum + " | lastSequenceNumber:"+lastSequenceNumber)

    if(thisSequenceNum == lastSequenceNumber + 1)
        sequenceGood = true
    //else
        //printl("MISSING SEQUENCE NUMBER DETECTED!!!")

    if(thisSequenceNum != null)
        lastSequenceNumber = thisSequenceNum
    */


    local index = msg.find("G1")
    if(index != null)
    {
        //printl("SEQGOOD: " + sequenceGood)
        msg = msg.slice(index + 2)
        //HandleG1(msg,sequenceGood)
        HandleG1(msg)
        commandHistory.insert(0,msg)
        commandHistory.pop()
    }
    
    index = msg.find("M117")
    if(index != null)
    {
        msg = msg.slice(index + 4)
        if(msg.find(" ") != null)
        {
            local message = msg.slice(msg.find(" ") + 1)
            EntFireByHandle(statusText, "addoutput", "message " + message, 0.00, null, null)
        }
        return
    }

    if(StartsWith(msg,"Changing"))
    {
        lastStatusUpdate = msg
        EntFireByHandle(masterScript, "RunScriptCode", "HandlePrinterStatus()", 0.10, null, null)
        //HandlePrinterStatus(msg)
    }

}.bindenv(this)

function GetSequenceNumber(input)
{
    if(input.find("N")==null)
        return null
    input = input.slice(input.find("N") + 1)
    return input.slice(0,input.find(" "))
}

function HandlePrinterStatus()
{
//"Operational" to "Starting"
//"Starting" to "Printing"

/*
    if(lastStatusUpdate.find("Operational") != null)
    {
        EntFireByHandle(statusText, "addoutput", "message Not Printing", 0.00, null, null)
        EntFireByHandle(statusText, "addoutput", "color 255 128 128", 0.00, null, null)
    }
*/
    if(lastStatusUpdate.find("'Starting' to 'Printing'") != null)
    {
        EntFireByHandle(statusText, "addoutput", "message Printing!", 0.00, null, null)
        EntFireByHandle(statusText, "addoutput", "color 128 128 255", 0.00, null, null)
        EntFire("killMe","kill")
        bIsPrinting = true
    }
    if(lastStatusUpdate.find("'Printing' to 'Finishing'") != null)
    {
        EntFireByHandle(statusText, "addoutput", "message Print Complete!", 0.00, null, null)
        EntFireByHandle(statusText, "addoutput", "color 60 255 60", 0.00, null, null)
        EntFire("@fireworks", "start", "", 0.00, null)
        EntFire("@fireworks", "stop", "", 1.00, null)
        EntFire("@finishSound", "Playsound", "", 0.00, null)
    }
}

//This is a work around that we delay the firing of this command so the telnet client always gets this as a single payload
function printSolo(msg)
{
    printl(msg)
}

function OnPostSpawn()
{
    printl("OnPostSpawn()")

    if(HPlayer == null)
        return

    EntFireByHandle(statusText, "addoutput", "message PREPARING...", 0.00, null, null)
    EntFireByHandle(statusText, "addoutput", "color 255 0 0", 0.00, null, null)

    printl("Starting drawing of temp graphs!")
    DrawGraphs()

    UpdateFileList()

    printl("Setting printer origin!")
    home = homeEntity.GetOrigin()
    printl(home)

    EntFireByHandle(masterScript, "RunScriptCode", "StartTerminalMonitoring()", 3.00, null, null)
}

function StartTerminalMonitoring()
{
    EntFireByHandle(statusText, "addoutput", "message Not Printing", 4.00, null, null)
    EntFireByHandle(statusText, "addoutput", "color 255 128 128", 4.00, null, null)

    printl("Starting terminal monitoring!")

    //Starts terminal monitoring
    EntFireByHandle(masterScript, "RunScriptCode", "printSolo(\"[OCTO]terminal\")", 0.5, null, null)
}

function Think()
{
    UpdateCommandHistory()
    EntFireByHandle(linesDrawnText, "addoutput", "message Lines Drawn = " + linesDrawn, 0.0, null, null)
}

function UpdateCommandHistory()
{
    EntFireByHandle(commandHistoryText[0], "addoutput", "message " + commandHistory[0], 0.0, null, null)
    EntFireByHandle(commandHistoryText[1], "addoutput", "message " + commandHistory[1], 0.0, null, null)
    EntFireByHandle(commandHistoryText[2], "addoutput", "message " + commandHistory[2], 0.0, null, null)
    EntFireByHandle(commandHistoryText[3], "addoutput", "message " + commandHistory[3], 0.0, null, null)
    EntFireByHandle(commandHistoryText[4], "addoutput", "message " + commandHistory[4], 0.0, null, null)
    EntFireByHandle(commandHistoryText[5], "addoutput", "message " + commandHistory[5], 0.0, null, null)
    EntFireByHandle(commandHistoryText[6], "addoutput", "message " + commandHistory[6], 0.0, null, null)
    EntFireByHandle(commandHistoryText[7], "addoutput", "message " + commandHistory[7], 0.0, null, null)
    EntFireByHandle(commandHistoryText[8], "addoutput", "message " + commandHistory[8], 0.0, null, null)
    EntFireByHandle(commandHistoryText[9], "addoutput", "message " + commandHistory[9], 0.0, null, null)
}