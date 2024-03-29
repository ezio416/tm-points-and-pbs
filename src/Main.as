// c 2024-03-29
// m 2024-03-29

bool         g_CurrentlyLoadingRecords = false;
uint         g_PlayersInServerLast     = 0;
uint         lastPbUpdate              = 0;
PBTime@[]    records;
const float  scale                     = UI::GetScale();
const string title                     = "\\$4C4" + Icons::ListOl + "\\$G Points And PBs";

void Main() {
    while (GetPermissionsOkay()) {
        yield();

        if (GetPlaygroundValidAndEditorNull() && S_Enabled) {
            startnew(UpdateRecords);
            lastPbUpdate = Time::Now;  // set this here to avoid triggering immediately

            while (GetPlaygroundValidAndEditorNull() && S_Enabled) {
                yield();

                if (g_PlayersInServerLast != GetPlayersInServerCount() || lastPbUpdate + 60000 < Time::Now) {
                    g_PlayersInServerLast = GetPlayersInServerCount();
                    startnew(UpdateRecords);
                    lastPbUpdate = Time::Now;  // bc we start it in a coro; don't want to run twice
                }
            }

            records = {};
        }

        while (!GetPlaygroundValidAndEditorNull() || !S_Enabled)
            yield();
    }

    const string msg = "Missing permissions! D:\nYou probably don't have permission to view records/PBs.\nThis plugin won't do anything.";

    warn(msg);
    UI::ShowNotification(title, msg, vec4(1.0f, 0.4f, 0.1f, 0.3f), 10000);
}

void Render() {
    if (S_Enabled) {
        const MLFeed::RaceDataProxy@ raceData = MLFeed::GetRaceData();

        if (raceData !is null) {
            bool foundBetter = false;

            for (uint i = 0; i < records.Length; i++) {
                PBTime@ pbTime = records[i];

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

    if (
        !S_Enabled
        || (S_HideWithOP && !UI::IsOverlayShown())
        || (S_HideWithGame && !UI::IsGameUIVisible())
        || !GetPermissionsOkay()
        || SoloModeExitCheck()
        || !GetPlaygroundValidAndEditorNull()
    )
        return;

    UI::SetNextWindowSize(400, 400, UI::Cond::FirstUseEver);

    if (UI::Begin(title, S_Enabled, UI::WindowFlags::NoTitleBar)) {
        if (GetApp().CurrentPlayground is null || GetApp().Editor !is null)
            UI::Text("Not in a map \\$999(or in editor).");
        else if (records.IsEmpty())
            UI::Text(g_CurrentlyLoadingRecords ? "Loading..." : "No records :(");
        else {
            uint nbCols = 3;  // rank, player and pb time are mandatory
            if (S_Clubs)
                nbCols++;
            if (S_Dates)
                nbCols++;
            if (S_SessionPB)
                nbCols++;

            UI::PushStyleColor(UI::Col::TableBorderLight, vec4(1.0f, 0.0f, 0.0f, 0.5f));  // should be UI::Col:Separator?

            if (UI::BeginTable("local-players-records", nbCols, UI::TableFlags::ScrollY | UI::TableFlags::Resizable)) {
                UI::TableSetupScrollFreeze(0, 1);
                UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, scale * 25.0f);  // rank
                if (S_Clubs)
                    UI::TableSetupColumn("Club", UI::TableColumnFlags::WidthFixed, scale * 50.0f);
                UI::TableSetupColumn("Player");
                UI::TableSetupColumn("PB Time", UI::TableColumnFlags::WidthFixed, scale * 80.0f);
                if (S_Dates)
                    UI::TableSetupColumn("PB Date", UI::TableColumnFlags::WidthFixed, scale * 80.0f);
                if (S_SessionPB)
                    UI::TableSetupColumn("Session", UI::TableColumnFlags::WidthFixed, scale * 80.0f);
                UI::TableHeadersRow();

                UI::ListClipper clipper(records.Length);
                while (clipper.Step()) {
                    for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                        PBTime@ pb = records[i];
                        UI::TableNextRow();

                        // highlight if updated -- note: record timestamps can appear in the future, so we just clamp and wait. // pb.recordTs <= Time::Stamp
                        const bool shouldHighlight = S_HIghlightRecent && pb.recordTs + 60 > uint(Time::Stamp);
                        if (shouldHighlight) {
                            const float hlAmount = 1.0f - Math::Clamp(float(int(Time::Stamp) - int(pb.recordTs)) / 60.0f, 0.0f, 1.0f);
                            UI::PushStyleColor(UI::Col::Text, vec4(0.3f, 0.9f, 0.1f, 1.0f) * hlAmount + vec4(1.0f, 1.0f, 1.0f, 1.0f) * (1.0f - hlAmount));
                        }

                        UI::TableNextColumn();
                        UI::Text(tostring(i + 1) + ".");

                        if (S_Clubs) {
                            UI::TableNextColumn();
                            if (pb.club.Length > 0)
                                UI::Text(ColoredString(pb.club));
                        }

                        UI::TableNextColumn();
                        UI::Text(pb.name);

                        UI::TableNextColumn();
                        UI::Text(pb.time > 0 ? Time::Format(pb.time) : "");

                        if (S_Dates) {
                            UI::TableNextColumn();
                            UI::Text(pb.recordTs > 0 ? Time::FormatString("%m-%d %H:%M", pb.recordTs) : "");
                        }

                        if (S_SessionPB) {
                            UI::TableNextColumn();
                            UI::Text(pb.sessionPb > 0 ? Time::Format(pb.sessionPb) : "");
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
    if (!GetPermissionsOkay())
        return;

    if (UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

string GetLocalPlayerWSID() {
    try {
        return GetApp().Network.ClientManiaAppPlayground.LocalUser.WebServicesUserId;
    } catch {
        return "";
    }
}

bool GetPermissionsOkay() {
    return Permissions::ViewRecords();
}

PBTime@[] GetPlayersPBs() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);

    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;
    if (CMAP is null)
        return {};

    if (CMAP.ScoreMgr is null || CMAP.UserMgr is null)
        return {};

    CSmPlayer@[]@ players = GetPlayersInServer();
    if (players is null || players.Length == 0)
        return {};

    MwFastBuffer<wstring> playerWSIDs = MwFastBuffer<wstring>();
    dictionary wsidToPlayer;

    for (uint i = 0; i < players.Length; i++) {
        playerWSIDs.Add(players[i].User.WebServicesUserId);
        @wsidToPlayer[players[i].User.WebServicesUserId] = players[i];
    }

    g_CurrentlyLoadingRecords = true;
    CWebServicesTaskResult_MapRecordListScript@ task = CMAP.ScoreMgr.Map_GetPlayerListRecordList(CMAP.UserMgr.Users[0].Id, playerWSIDs, GetApp().RootMap.MapInfo.MapUid, "PersonalBest", "", "", "");
    while (task.IsProcessing)
        yield();
    g_CurrentlyLoadingRecords = false;

    if (task.HasFailed || !task.HasSucceeded) {
        warn("Requesting records failed. Type,Code,Desc: " + task.ErrorType + ", " + task.ErrorCode + ", " + task.ErrorDescription);
        return {};
    }

    /* note:
        - usually we expect `task.MapRecordList.Length != players.Length`
        - `players[i].User.WebServicesUserId != task.MapRecordList[i].WebServicesUserId`
       so we use a dictionary to look up the players (wsidToPlayer we set up earlier)
    */

    const string localWSID = GetLocalPlayerWSID();

    PBTime@[] ret;

    for (uint i = 0; i < task.MapRecordList.Length; i++) {
        CMapRecord@ Record = task.MapRecordList[i];
        CSmPlayer@ _p = cast<CSmPlayer@>(wsidToPlayer[Record.WebServicesUserId]);
        if (_p is null) {
            warn("Failed to lookup player from temp dict");
            continue;
        }

        ret.InsertLast(PBTime(_p, Record, Record.WebServicesUserId == localWSID));
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

uint GetPlayersInServerCount() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    CSmArenaClient@ Playground = cast<CSmArenaClient@>(App.CurrentPlayground);
    if (Playground is null)
        return 0;

    return Playground.Players.Length;
}

bool GetPlaygroundValidAndEditorNull() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    return App.CurrentPlayground !is null && App.Editor is null;
}

CSmPlayer@[]@ GetPlayersInServer() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    CSmArenaClient@ Playground = cast<CSmArenaClient@>(App.CurrentPlayground);
    if (Playground is null)
        return {};

    CSmPlayer@[] ret;

    for (uint i = 0; i < Playground.Players.Length; i++) {
        CSmPlayer@ Player = cast<CSmPlayer@>(Playground.Players[i]);
        if (Player !is null)
            ret.InsertLast(Player);
    }

    return ret;
}

void RetryRecordsSoon() {
    sleep(500);
    UpdateRecords();
}

bool SoloModeExitCheck() {
    return S_HideInSoloMode && GetApp().PlaygroundScript !is null;
}

void UpdateRecords() {
    lastPbUpdate = Time::Now;
    PBTime@[] newPBs = GetPlayersPBs();

    if (newPBs.Length > 0)  // empty arrays are returned on e.g., http error
        records = newPBs;
}

class PBTime {
    string club;
    bool   isLocalPlayer = false;
    string name;
    uint   sessionPb     = 0;
    uint   time          = 0;
    uint   recordTs      = 0;
    string wsid;

    PBTime(CSmPlayer@ Player, CMapRecord@ Record, bool localPlayer = false) {
        if (Player.User !is null) {
            wsid = Player.User.WebServicesUserId;  // rare null pointer exception here? `Invalid address for member ID 03002000. This is likely a Nadeo bug! Setting it to null!`
            name = Player.User.Name;
            club = Player.User.ClubTag;
        }

        isLocalPlayer = localPlayer;

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
