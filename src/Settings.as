[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Show when Overlay Hidden?" description="Whether to show the window regardless of if the Openplanet overlay is hidden or not."]
bool S_ShowWhenUIHidden = true;

[Setting category="General" name="Lock Window when Overlay Hidden?" description="No effect unless 'Show when Overlay Hidden' is checked."]
bool S_LockWhenUIHidden = true;

[Setting category="General" name="Show Title Bar when Unlocked?" description="When the overlay is shown and/or the window isn't locked, it will have a title bar with a little (X) to close it."]
bool S_TitleBarWhenUnlocked = true;

[Setting category="General" name="Hide Window in Solo Play?" description="When checked, the window will only show in multiplayer servers, not local games."]
bool S_HideInSoloMode = true;

[Setting category="General" name="Hide Top Info?" description="The top info (showing refresh btn, #Players, and your rank) will be hidden if this is checked."]
bool S_HideTopInfo = false;

[Setting category="General" name="Map Name in Top Info?" description="Show the map name in the top info."]
bool S_TopInfoMapName = true;

[Setting category="General" name="Show club tags" description="Will show club tags in the list. Club tags have a slight performance impact."]
bool S_Clubs = true;

[Setting category="General" name="Show PB dates"]
bool S_Dates = false;

// don't expose via settings -- not sure it's that useful and mucks up formatting.
// [Setting category="General" name="Show Replay Download Button?" description="Will show a button to download a player's PB ghost/replay"]
const bool S_ShowReplayBtn = false;

[Setting category="General" name="Highlight Recent PBs?" description="Will highlight PBs set within the last 60s."]
bool S_ShowRecentPBsInGreen = true;

#if DEPENDENCY_MLFEEDRACEDATA
[Setting category="General" name="Disable Live Updates via MLFeed?" description="Disable this to skip checking current race data for better times."]
#endif
bool S_SkipMLFeedCheck = false;

[Setting category="General" name="Hotkey Active?" description="The hotkey will only work when this is checked."]
bool S_HotkeyEnabled = false;

[Setting category="General" name="Show/Hide Hotkey" description="The hotkey to toggle the list of PBs window."]
VirtualKey S_Hotkey = VirtualKey::F2;
