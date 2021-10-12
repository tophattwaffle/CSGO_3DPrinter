IncludeScript("vs_library")
IncludeScript("thw_util")
IncludeScript("tempHandler")
IncludeScript("previewHandler")

masterScript <- Entities.FindByName(null, "@masterScript")

latestSeenTempMessage <- null
homeEntity <- Entities.FindByName(null, "@home")
home <- null

//Handles all incoming messages from the outside
::IncomingMessage <- function(msg)
{
    if(msg.find("Send: ") != null)
        msg = msg.slice(6)
    
    if(StartsWith(msg,"N"))
    {
        msg = msg.slice(msg.find(" ") + 1)
    }
    if(StartsWith(msg,"T:"))
        HandleTemps(msg)
    else if(msg.find("G1") != null)
        HandleG1(msg)

}.bindenv(this)

function OnPostSpawn()
{
    printl("OnPostSpawn()")

    printl("Starting drawing of temp graphs!")
    DrawGraphs()

    printl("Setting printer origin!")
    home = homeEntity.GetOrigin()
    printl(home)
}

/* Not used yet.
function Think()
{

}
*/