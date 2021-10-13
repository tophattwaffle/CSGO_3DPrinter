printl("Loaded thw_util.nut")

//Checks if the left string starts with the right string.
function StartsWith(left, right, caseSensitive = true)
{
    if(!caseSensitive)
    {
        left = left.toupper()
        right = right.toupper()
    }

    for(local i = 0; i < right.len(); i++)
    {
        if(left[i] != right[i])
            return false
    }
    return true
}

//Given 3 vectors, where vec2 is shared - returns the degrees between them
function FindAngleBetweenLines(vec1, vec2, vec3)
{
    return abs(atan((vec1.y - vec2.y) / (vec1.x - vec2.x)) * 180 / PI - atan((vec2.y - vec3.y) / (vec2.x - vec3.x)) * 180 / PI)
}

//Given 3 vectors, where vec2 is shared - returns the degrees between them
//Sam#2693 on Discord provided this. I have yet to test it.
function FindAngleBetweenLinesAlt(vec1, vec2, vec3)
{
    d1 = vec2 - vec1;
    d2 = vec2 - vec3;
    d1.Norm();
    d2.Norm();
    angle = RAD2DEG * acos( d1.Dot(d2) );
    return angle
}

function FindAngleBetweenLinesFromFixed(vec1, vec2)
{
    return atan((vec1.y - vec2.y) / (vec1.x - vec2.x)) * 180 / PI - 45
}

//Creates a volume that you can use for things like trigger_multiple and such
//for solids, you use solid 2 and delete collisiongroup
::CreateTrigger <- function(classname,targetname,origin,angles,mins,maxs,spawnflags=1)
{
    trigger <- Entities.CreateByClassname(classname);
    EntFireByHandle(trigger, "AddOutput", "targetname " + targetname, 0, null, null);
    trigger.SetAngles(angles.x, angles.y, angles.z);
    trigger.SetOrigin(origin);
    trigger.SetSize(mins, maxs);
    trigger.__KeyValueFromInt("spawnflags", spawnflags);
    trigger.__KeyValueFromInt("Solid", 3); //Oriented
    trigger.__KeyValueFromInt("CollisionGroup", 10); // Non-Solid
    return trigger
}