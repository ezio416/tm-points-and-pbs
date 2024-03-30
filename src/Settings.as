[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Hide with game UI"]
bool S_HideWithGame = true;

[Setting category="General" name="Hide with Openplanet UI"]
bool S_HideWithOP = false;

[Setting category="General" name="Show window in solo"]
bool S_ShowInSoloMode = false;

[Setting category="General" name="Auto-size window"]
bool S_AutoSize = false;

[Setting category="General" name="Show column headers"]
bool S_Headers = true;

[Setting category="General" name="Show placement #"]
bool S_Ranks = false;

[Setting category="General" name="Show Ranked division icons"]
bool S_Div = true;

[Setting category="General" name="Show club tags"]
bool S_Clubs = true;

[Setting category="General" name="Auto-size player name column"]
bool S_AutoPlayerCol = true;

enum IconType {
    None,
    Real,
    Simple
}

[Setting category="General" name="Show Ranked teams"]
bool S_Team = true;

[Setting category="General" name="Show Ranked points"]
bool S_Points = true;

[Setting category="General" name="Medal icons"]
IconType S_Medal = IconType::Simple;

[Setting category="General" name="Show PB dates"]
bool S_Dates = true;

[Setting category="General" name="Show session PB"]
bool S_SessionPB = true;

[Setting category="General" name="Highlight Recent PBs?" description="highlights PBs set within the last minute"]
bool S_HIghlightRecent = true;

[Setting category="General" name="Highlight color" color]
vec4 S_HighlightColor = vec4(0.3f, 0.9f, 0.1f, 1.0f);

[Setting category="General" name="Column separator color" color]
vec4 S_ColSepColor = vec4(0.0f, 1.0f, 1.0f, 0.5f);
