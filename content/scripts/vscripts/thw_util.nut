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