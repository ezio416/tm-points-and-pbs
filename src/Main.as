// c 2024-03-29
// m 2024-03-29

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
    // LoadIconsRanked();
    // LoadIconsRoyal();

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    while (Permissions::ViewRecords()) {
        yield();

        if (PlaygroundValidAndEditorNull() && S_Enabled) {
            startnew(UpdateRecords);
            lastPbUpdate = Time::Now;  // set this here to avoid triggering immediately

            while (PlaygroundValidAndEditorNull() && S_Enabled) {
                yield();

                int playersInServer = -1;

                CSmArenaClient@ Playground = cast<CSmArenaClient@>(App.CurrentPlayground);

                if (Playground !is null)
                    playersInServer = int(Playground.Players.Length);

                if (playersInServerLast != playersInServer || lastPbUpdate + 60000 < Time::Now) {
                    playersInServerLast = playersInServer;
                    startnew(UpdateRecords);
                    lastPbUpdate = Time::Now;  // bc we start it in a coro; don't want to run twice
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

    if (S_Enabled) {
        const MLFeed::RaceDataProxy@ raceData = MLFeed::GetRaceData();

        if (raceData !is null) {
            bool foundBetter = false;

            for (uint i = 0; i < records.Length; i++) {
                PBTime@ pbTime = records[i];

                playerColumnWidth = Math::Max(playerColumnWidth, Draw::MeasureString(pbTime.name).x);

                const MLFeed::PlayerCpInfo@ player = raceData.GetPlayer(pbTime.name);
                if (player is null || player.bestTime < 1)
                    continue;

                pbTime.sessionPb = player.bestTime;

                if (pbTime.sessionPb < pbTime.time || pbTime.time == 0) {
                    pbTime.time = pbTime.sessionPb;
                    pbTime.recordTs = Time::Stamp;
                    foundBetter = true;
                }
            }

            if (foundBetter)
                records.SortAsc();
        }
    }

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

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
            if (S_Rank)      nbCols++;
            if (S_Clubs)     nbCols++;
            if (S_Dates)     nbCols++;
            if (S_SessionPB) nbCols++;

            UI::PushStyleColor(UI::Col::TableBorderLight, S_ColSepColor);  // should be UI::Col:Separator?

            if (UI::BeginTable("local-players-records", nbCols, UI::TableFlags::ScrollY | UI::TableFlags::Resizable)) {
                UI::TableSetupScrollFreeze(0, 1);
                if (S_Rank)  UI::TableSetupColumn("#",    UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 20.0f);
                if (S_Clubs) UI::TableSetupColumn("Club", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 50.0f);

                if (S_AutoPlayerCol)
                    UI::TableSetupColumn("Player", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, playerColumnWidth);
                else
                    UI::TableSetupColumn("Player", UI::TableColumnFlags::NoResize);

                                 UI::TableSetupColumn("PB Time", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 80.0f);
                if (S_Dates)     UI::TableSetupColumn("PB Date", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 75.0f);
                if (S_SessionPB) UI::TableSetupColumn("Session", UI::TableColumnFlags::NoResize | UI::TableColumnFlags::WidthFixed, scale * 80.0f);
                if (S_Headers)   UI::TableHeadersRow();

                UI::ListClipper clipper(records.Length);
                while (clipper.Step()) {
                    for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                        PBTime@ pb = records[i];
                        UI::TableNextRow();

                        const bool shouldHighlight = S_HIghlightRecent && pb.recordTs + 60 > uint(Time::Stamp);
                        if (shouldHighlight) {
                            const float hlAmount = 1.0f - Math::Clamp(float(int(Time::Stamp) - int(pb.recordTs)) / 60.0f, 0.0f, 1.0f);
                            UI::PushStyleColor(UI::Col::Text, S_HighlightColor * hlAmount + vec4(1.0f, 1.0f, 1.0f, 1.0f) * (1.0f - hlAmount));
                        }

                        if (S_Rank) {
                            UI::TableNextColumn();
                            UI::Text(tostring(i + 1) + ".");
                        }

                        if (S_Clubs) {
                            UI::TableNextColumn();
                            if (pb.club.Length > 0)
                                UI::Text(ColoredString(pb.club));
                        }

                        UI::TableNextColumn();
                        UI::Text(pb.name);

                        UI::TableNextColumn();
                        UI::Text(pb.time > 0 ? Time::Format(pb.time) : "");
                        if (S_Medal != IconType::None) {
                            uint medal = 0;

                            if (pb.time > 0) {
                                if (pb.time < authorTime)
                                    medal = 4;
                                else if (pb.time < goldTime)
                                    medal = 3;
                                else if (pb.time < silverTime)
                                    medal = 2;
                                else if (pb.time < bronzeTime)
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
                                UI::Text(pb.time > 0 ? medalColors[medal] + Icons::Circle : "");
                            }
                        }

                        if (S_Dates) {
                            UI::TableNextColumn();
                            UI::Text(pb.recordTs > 0 ? Time::FormatString("%m-%d %H:%M", pb.recordTs) : "");
                        }

                        if (S_SessionPB) {
                            UI::TableNextColumn();
                            UI::Text(pb.sessionPb > 0 ? Time::Format(pb.sessionPb) : "");

                            if (S_Medal != IconType::None) {
                                uint medal = 0;

                                if (pb.sessionPb > 0) {
                                    if (pb.sessionPb < authorTime)
                                        medal = 4;
                                    else if (pb.sessionPb < goldTime)
                                        medal = 3;
                                    else if (pb.sessionPb < silverTime)
                                        medal = 2;
                                    else if (pb.sessionPb < bronzeTime)
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
                                    UI::Text(pb.sessionPb > 0 ? medalColors[medal] + Icons::Circle : "");
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
    string club;
    string name;
    uint   sessionPb = 0;
    uint   time      = 0;
    uint   recordTs  = 0;
    string wsid;

    PBTime() { }
    PBTime(CSmPlayer@ Player, CMapRecord@ Record) {
        if (Player.User !is null) {
            wsid = Player.User.WebServicesUserId;  // rare null pointer exception here? `Invalid address for member ID 03002000. This is likely a Nadeo bug! Setting it to null!`
            name = Player.User.Name;
            club = Player.User.ClubTag;
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
}
