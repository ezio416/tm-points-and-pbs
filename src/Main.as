// c 2024-03-29
// m 2024-04-02

bool           gettingRanks        = false;
uint           lastPbUpdate        = 0;
bool           loadingRecords      = false;
vec2           iconOffset;
vec2           iconSize            = vec2();
UI::Texture@[] iconsMedals;
UI::Texture@[] iconsRanked;
UI::Texture@[] iconsRoyal;
const string[] medalColors         = { "\\$444", "\\$964", "\\$899", "\\$DB4", "\\$071" };
float          playerColumnWidth   = 0.0f;
int            playersInServerLast = 0;
PBTime@[]      records;
const float    scale               = UI::GetScale();
const string   title               = "\\$4C4" + Icons::ListOl + "\\$G Points And PBs";

void Main() {
    iconOffset = vec2(1.0f, 0.2f)    * scale * 10.0f;
    iconSize   = vec2(1.2642f, 1.0f) * scale * 20.0f;

    LoadIconsMedals();
    LoadIconsRanked();
    // LoadIconsRoyal();

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    while (Permissions::ViewRecords()) {
        yield();

        if (PlaygroundValidAndEditorNull() && S_Enabled) {
            while (PlaygroundValidAndEditorNull() && S_Enabled) {
                yield();

                CSmArenaClient@ Playground = cast<CSmArenaClient@>(App.CurrentPlayground);

                const int playersInServer = Playground is null ? 0 : Playground.Players.Length;

                if (playersInServerLast != playersInServer || lastPbUpdate + 60000 < Time::Now) {
                    playersInServerLast = playersInServer;

                    Meta::PluginCoroutine@ coro = startnew(UpdateRecords);
                    while (coro.IsRunning())
                        yield();

                    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
                    CTrackManiaNetworkServerInfo@ ServerInfo = cast<CTrackManiaNetworkServerInfo@>(Network.ServerInfo);

                    if (ServerInfo.CurGameModeStr == "TM_Teams_Matchmaking_Online") {
                        @coro = startnew(GetPlayerMMRanks);
                        while (coro.IsRunning())
                            yield();
                    }
                }
            }

            records = {};
        }

        while (!PlaygroundValidAndEditorNull() || !S_Enabled)
            yield();
    }

    const string msg = "Missing permissions! D:\nYou probably don't have permission to view records/PBs.\nThis plugin won't do anything.";

    warn(msg);
    UI::ShowNotification(title, msg, vec4(1.0f, 0.4f, 0.1f, 0.3f), 10000);
}

void Render() {
    playerColumnWidth = 0.0f;

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CTrackManiaNetworkServerInfo@ ServerInfo = cast<CTrackManiaNetworkServerInfo@>(Network.ServerInfo);

    const bool inRanked = ServerInfo.CurGameModeStr == "TM_Teams_Matchmaking_Online";

    if (S_Enabled) {
        const MLFeed::RaceDataProxy@ raceData = MLFeed::GetRaceData();

        if (raceData !is null) {
            bool foundBetter = false;

            for (uint i = 0; i < records.Length; i++) {
                PBTime@ player = records[i];

                playerColumnWidth = Math::Max(playerColumnWidth, Draw::MeasureString((inRanked && S_Team ? Icons::Circle + " " : "") + player.name).x);

                const MLFeed::PlayerCpInfo@ cpInfo = raceData.GetPlayer(player.name);
                if (cpInfo is null || cpInfo.bestTime < 1)
                    continue;

                player.sessionPB = cpInfo.bestTime;

                if (player.sessionPB < player.time || player.time == 0) {
                    player.time = player.sessionPB;
                    player.recordTs = Time::Stamp;
                    foundBetter = true;
                }
            }

            if (foundBetter)
                records.SortAsc();
        }
    }

    if (
        !S_Enabled
        || !Permissions::ViewRecords()
        || (S_HideWithGame && !UI::IsGameUIVisible())
        || (S_HideWithOP && !UI::IsOverlayShown())
        || (!S_ShowInSoloMode && App.PlaygroundScript !is null)
        || !PlaygroundValidAndEditorNull()
        || App.RootMap is null  // probably don't need to check but just to be safe
    )
        return;

    const uint authorTime = App.RootMap.TMObjective_AuthorTime;
    const uint goldTime   = App.RootMap.TMObjective_GoldTime;
    const uint silverTime = App.RootMap.TMObjective_SilverTime;
    const uint bronzeTime = App.RootMap.TMObjective_BronzeTime;

    int windowFlags = UI::WindowFlags::NoTitleBar;
    if (S_AutoSize)
        windowFlags |= UI::WindowFlags::AlwaysAutoResize;

    if (UI::Begin(title, S_Enabled, windowFlags)) {
        if (App.CurrentPlayground is null || App.Editor !is null)
            UI::Text("Not in a map \\$999(or in editor).");
        else if (records.IsEmpty())
            UI::Text(loadingRecords ? "Loading..." : "No records :(");
        else {
            uint nbCols = 2;
            if (S_Ranks)              nbCols++;
            if (inRanked && S_Div)    nbCols++;
            if (S_Clubs)              nbCols++;
            if (inRanked && S_Points) nbCols++;
            if (S_Dates)              nbCols++;
            if (S_SessionPB)          nbCols++;

            UI::PushStyleColor(UI::Col::TableBorderLight, S_ColSepColor);  // should be UI::Col:Separator?

            if (UI::BeginTable("local-players-records", nbCols, UI::TableFlags::ScrollY | UI::TableFlags::Resizable)) {
                UI::TableSetupScrollFreeze(0, 1);
                if (S_Ranks)           UI::TableSetupColumn("#",    UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 20.0f);
                if (inRanked && S_Div) UI::TableSetupColumn("Div",  UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 30.0f);
                if (S_Clubs)           UI::TableSetupColumn("Club", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 50.0f);

                if (S_AutoPlayerCol)
                    UI::TableSetupColumn("Player", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, playerColumnWidth);
                else
                    UI::TableSetupColumn("Player", UI::TableColumnFlags::NoResize);

                if (inRanked && S_Points) UI::TableSetupColumn("Pts",     UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 20.0f);
                                          UI::TableSetupColumn("PB Time", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 80.0f);
                if (S_Dates)              UI::TableSetupColumn("PB Date", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 75.0f);
                if (S_SessionPB)          UI::TableSetupColumn("Session", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 80.0f);
                if (S_Headers)            UI::TableHeadersRow();

                UI::ListClipper clipper(records.Length);
                while (clipper.Step()) {
                    for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                        PBTime@ player = records[i];
                        UI::TableNextRow();

                        const bool shouldHighlight = S_HIghlightRecent && player.recordTs + 60 > uint(Time::Stamp);
                        if (shouldHighlight) {
                            const float hlAmount = 1.0f - Math::Clamp(float(int(Time::Stamp) - int(player.recordTs)) / 60.0f, 0.0f, 1.0f);
                            UI::PushStyleColor(UI::Col::Text, S_HighlightColor * hlAmount + vec4(1.0f, 1.0f, 1.0f, 1.0f) * (1.0f - hlAmount));
                        }

                        if (S_Ranks) {
                            UI::TableNextColumn();
                            UI::Text(tostring(i + 1) + ".");
                        }

                        if (inRanked && S_Div) {
                            UI::TableNextColumn();
                            UI::Texture@ icon = player.divisionIcon;
                            if (icon !is null)
                                UI::Image(icon, iconSize);
                            else
                                UI::Dummy(iconSize);
                        }

                        if (S_Clubs) {
                            UI::TableNextColumn();
                            if (player.club.Length > 0)
                                UI::Text(ColoredString(player.club));
                        }

                        UI::TableNextColumn();
                        const uint team = player.score !is null ? player.score.TeamNum : 0;
                        const string color = team == 2 ? "\\$E22" : team == 1 ? "\\$37F" : "\\$888";
                        UI::Text((inRanked && S_Team ? (color + Icons::Circle + "\\$G ") : "") + player.name);

                        if (inRanked && S_Points) {
                            UI::TableNextColumn();
                            UI::Text(tostring(player.score !is null ? player.score.Points : 0));
                        }

                        UI::TableNextColumn();
                        UI::Text(player.time > 0 ? Time::Format(player.time) : "");
                        if (S_Medal != IconType::None) {
                            uint medal = 0;

                            if (player.time > 0) {
                                if (player.time <= authorTime)
                                    medal = 4;
                                else if (player.time <= goldTime)
                                    medal = 3;
                                else if (player.time <= silverTime)
                                    medal = 2;
                                else if (player.time <= bronzeTime)
                                    medal = 1;
                            }

                            UI::SameLine();

                            if (S_Medal == IconType::Real) {
                                UI::Texture@ icon = GetIconMedal(medal);
                                UI::SetCursorPos(UI::GetCursorPos() - iconOffset);

                                if (icon !is null)
                                    UI::Image(icon, iconSize);
                                else
                                    UI::Dummy(iconSize);
                            } else {
                                UI::SetCursorPos(UI::GetCursorPos() - vec2(iconOffset.x * 0.5f, iconOffset.y * -0.5f));
                                UI::Text(player.time > 0 ? medalColors[medal] + Icons::Circle : "");
                            }
                        }

                        if (S_Dates) {
                            UI::TableNextColumn();
                            UI::Text(player.recordTs > 0 ? Time::FormatString("%m-%d %H:%M", player.recordTs) : "");
                        }

                        if (S_SessionPB) {
                            UI::TableNextColumn();
                            UI::Text(player.sessionPB > 0 ? Time::Format(player.sessionPB) : "");

                            if (S_Medal != IconType::None) {
                                uint medal = 0;

                                if (player.sessionPB > 0) {
                                    if (player.sessionPB <= authorTime)
                                        medal = 4;
                                    else if (player.sessionPB <= goldTime)
                                        medal = 3;
                                    else if (player.sessionPB <= silverTime)
                                        medal = 2;
                                    else if (player.sessionPB <= bronzeTime)
                                        medal = 1;
                                }

                                UI::SameLine();

                                if (S_Medal == IconType::Real) {
                                    UI::Texture@ icon = GetIconMedal(medal);
                                    UI::SetCursorPos(UI::GetCursorPos() - iconOffset);

                                    if (icon !is null)
                                        UI::Image(icon, iconSize);
                                    else
                                        UI::Dummy(iconSize);
                                } else {
                                    UI::SetCursorPos(UI::GetCursorPos() - vec2(iconOffset.x * 0.5f, iconOffset.y * -0.5f));
                                    UI::Text(player.sessionPB > 0 ? medalColors[medal] + Icons::Circle : "");
                                }
                            }
                        }

                        if (shouldHighlight)
                            UI::PopStyleColor();
                    }
                }

                UI::EndTable();
            }

            UI::PopStyleColor();
        }
    }

    UI::End();
}

void RenderMenu() {
    if (!Permissions::ViewRecords())
        return;

    if (UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

UI::Texture@ GetIconMedal(const uint medal) {
    if (medal < iconsMedals.Length)
        return iconsMedals[medal];

    return null;
}

void GetPlayerMMRanks() {
    while (gettingRanks)
        yield();

    gettingRanks = true;

    trace("getting players' MM ranks");

    dictionary@ pbTimes = dictionary();

    if (records.Length == 0) {
        warn("no records");
        gettingRanks = false;
        return;
    }

    for (uint i = 0; i < records.Length; i++)
        pbTimes[records[i].accountId] = @records[i];

    sleep(500);

    while (!NadeoServices::IsAuthenticated("NadeoLiveServices"))
        yield();

    Net::HttpRequest@ req = NadeoServices::Get(
        "NadeoLiveServices",
        "https://meet.trackmania.nadeo.club/api/matchmaking/2/leaderboard/players?players[]=" + string::Join(pbTimes.GetKeys(), "&players[]=")
    );
    req.Start();
    while (!req.Finished())
        yield();

    const int code = req.ResponseCode();
    const string text = req.String();

    if (code != 200) {
        warn("bad API response (" + code + "): " + text + " | " + req.Error());
        gettingRanks = false;
        return;
    }

    Json::Value@ loaded = Json::Parse(text);

    Json::Type type = loaded.GetType();
    if (type != Json::Type::Object) {
        warn("bad JSON type (loaded): " + tostring(type));
        gettingRanks = false;
        return;
    }

    if (!loaded.HasKey("results")) {
        warn("JSON response missing key 'results'");
        gettingRanks = false;
        return;
    }

    Json::Value@ results = loaded["results"];

    type = results.GetType();
    if (type != Json::Type::Array) {
        warn("bad JSON type (results): " + tostring(type));
        gettingRanks = false;
        return;
    }

    if (results.Length == 0) {
        warn("no results");
        gettingRanks = false;
        return;
    }

    for (uint i = 0; i < results.Length; i++) {
        Json::Value@ result = results[i];

        if (!result.HasKey("player") || !result.HasKey("score")) {
            warn("missing key 'player' or 'score'");
            continue;
        }

        PBTime@ record = cast<PBTime@>(pbTimes[result["player"]]);
        if (record is null) {
            warn("null record");
            continue;
        }

        record.mmPoints = result["score"];
    }

    trace("got players' MM ranks");

    gettingRanks = false;
}

void LoadIconsMedals() {
    iconsMedals = {};
    iconsMedals.InsertLast(null);

    UI::Texture@ tex;

    for (uint i = 1; i < 5; i++) {
        yield();

        @tex = UI::LoadTexture("src/Assets/Medals/" + i + ".png");

        if (tex !is null)
            iconsMedals.InsertLast(tex);
        else
            warn("null texture for medal " + i);
    }
}

void LoadIconsRanked() {
    iconsRanked = {};
    iconsRanked.InsertLast(null);

    UI::Texture@ tex;

    for (uint i = 1; i < 14; i++) {
        yield();

        @tex = UI::LoadTexture("src/Assets/Ranked/" + i + ".png");

        if (tex !is null)
            iconsRanked.InsertLast(tex);
        else
            warn("null texture for ranked " + i);
    }
}

void LoadIconsRoyal() {
    iconsRoyal = {};
    iconsRoyal.InsertLast(null);

    UI::Texture@ tex;

    for (uint i = 1; i < 5; i++) {
        yield();

        @tex = UI::LoadTexture("src/Assets/Royal/" + i + ".png");

        if (tex !is null)
            iconsRoyal.InsertLast(tex);
        else
            warn("null texture for royal " + i);
    }
}

PBTime@[] GetPlayersPBs() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);

    CSmArenaClient@ Playground = cast<CSmArenaClient@>(App.CurrentPlayground);
    if (Playground is null)
        return {};

    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;
    if (CMAP is null || CMAP.ScoreMgr is null || CMAP.UserMgr is null)
        return {};

    CSmPlayer@[] Players;
    for (uint i = 0; i < Playground.Players.Length; i++) {
        CSmPlayer@ Player = cast<CSmPlayer@>(Playground.Players[i]);
        if (Player !is null)
            Players.InsertLast(Player);
    }

    MwFastBuffer<wstring> playerWSIDs = MwFastBuffer<wstring>();
    dictionary wsidToPlayer;

    for (uint i = 0; i < Players.Length; i++) {
        if (Players[i].User is null)
            continue;

        playerWSIDs.Add(Players[i].User.WebServicesUserId);
        @wsidToPlayer[Players[i].User.WebServicesUserId] = Players[i];
    }

    loadingRecords = true;
    CWebServicesTaskResult_MapRecordListScript@ task = CMAP.ScoreMgr.Map_GetPlayerListRecordList(CMAP.UserMgr.Users[0].Id, playerWSIDs, GetApp().RootMap.MapInfo.MapUid, "PersonalBest", "", "", "");
    while (task.IsProcessing)
        yield();
    loadingRecords = false;

    if (task.HasFailed || !task.HasSucceeded) {
        warn("Requesting records failed. Type,Code,Desc: " + task.ErrorType + ", " + task.ErrorCode + ", " + task.ErrorDescription);
        return {};
    }

    /* note:
        - usually we expect `task.MapRecordList.Length != players.Length`
        - `players[i].User.WebServicesUserId != task.MapRecordList[i].WebServicesUserId`
       so we use a dictionary to look up the players (wsidToPlayer we set up earlier)
    */

    PBTime@[] ret;

    for (uint i = 0; i < task.MapRecordList.Length; i++) {
        CMapRecord@ Record = task.MapRecordList[i];
        CSmPlayer@ _p = cast<CSmPlayer@>(wsidToPlayer[Record.WebServicesUserId]);
        if (_p is null) {
            warn("Failed to lookup player from temp dict");
            continue;
        }

        ret.InsertLast(PBTime(_p, Record));
        // remove the player so we can quickly get all players in server that don't have records
        wsidToPlayer.Delete(Record.WebServicesUserId);
    }

    string[]@ playersWithoutPB = wsidToPlayer.GetKeys();

    for (uint i = 0; i < playersWithoutPB.Length; i++) {
        string wsid = playersWithoutPB[i];
        CSmPlayer@ player = cast<CSmPlayer@>(wsidToPlayer[wsid]);

        try {
            // sometimes we get a null pointer exception here on player.User.WebServicesUserId
            ret.InsertLast(PBTime(player, null));
        } catch {
            warn("Got exception updating records. Will retry in 500ms. Exception: " + getExceptionInfo());
            startnew(RetryRecordsSoon);
        }
    }

    ret.SortAsc();

    return ret;
}

bool PlaygroundValidAndEditorNull() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    return App.CurrentPlayground !is null && App.Editor is null;
}

void RetryRecordsSoon() {
    sleep(500);
    UpdateRecords();
}

void UpdateRecords() {
    lastPbUpdate = Time::Now;
    PBTime@[] newPBs = GetPlayersPBs();

    if (newPBs.Length > 0)  // empty arrays are returned on e.g., http error
        records = newPBs;
}

class PBTime {
    string         accountId;
    string         club;
    uint           mmPoints  = 0;
    string         name;
    CSmArenaScore@ score;
    uint           sessionPB = 0;
    uint           time      = 0;
    uint           recordTs  = 0;

    PBTime() { }
    PBTime(CSmPlayer@ player, CMapRecord@ Record) {
        if (player is null)
            return;

        if (player.Score !is null)
            @score = player.Score;

        if (player.User !is null) {
            accountId = player.User.WebServicesUserId;  // rare null pointer exception here? `Invalid address for member ID 03002000. This is likely a Nadeo bug! Setting it to null!`
            club      = player.User.ClubTag;
            name      = player.User.Name;
        }

        if (Record !is null) {
            recordTs = Record.Timestamp;
            time     = Record.Time;
        }
    }

    int opCmp(PBTime@ other) const {
        if (time == 0)
            return (other.time == 0 ? 0 : 1);  // one or both PB unset

        if (other.time == 0 || time < other.time)
            return -1;

        if (time == other.time)
            return 0;

        return 1;
    }

    uint get_division() {
        if (mmPoints == 0)   return 0;   // none
        if (mmPoints < 300)  return 1;   // b1
        if (mmPoints < 600)  return 2;   // b2
        if (mmPoints < 1000) return 3;   // b3
        if (mmPoints < 1300) return 4;   // s1
        if (mmPoints < 1600) return 5;   // s2
        if (mmPoints < 2000) return 6;   // s3
        if (mmPoints < 2300) return 7;   // g1
        if (mmPoints < 2600) return 8;   // g2
        if (mmPoints < 3000) return 9;   // g3
        if (mmPoints < 3300) return 10;  // m1
        if (mmPoints < 3600) return 11;  // m2
        if (mmPoints < 4000) return 12;  // m3
        return 13;  // tm
    }

    UI::Texture@ get_divisionIcon() {
        const uint div = division;

        if (div < iconsRanked.Length)
            return iconsRanked[div];

        return null;
    }
}
