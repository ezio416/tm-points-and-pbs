// c 2024-03-29
// m 2024-03-29

bool         g_CurrentlyLoadingRecords = false;
uint         g_PlayersInServerLast     = 0;
uint         lastLPR_Rank              = 0;
uint         lastLPR_Time              = 0;
uint         lastPbUpdate              = 0;
PBTime@[]    records;
const string title                     = "\\$4C4" + Icons::ListOl + "\\$G Points And PBs";

void Main() {
    // when current playground becomes not-null, get records
    // when player count changes, get records
    // when playground goes null, reset
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

    NotifyMissingPermissions();
}

UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    if (!down || !S_HotkeyEnabled)
        return UI::InputBlocking::DoNothing;

    if (key == S_Hotkey) {
        if (!GetPlaygroundValidAndEditorNull() || SoloModeExitCheck())
            return UI::InputBlocking::DoNothing;

        S_Enabled = !S_Enabled;
        UI::ShowNotification(Meta::ExecutingPlugin().Name, "Toggled visibility", vec4(0.1, 0.4, 0.8, 0.4));
        return UI::InputBlocking::Block;
    }

    return UI::InputBlocking::DoNothing;
}

void Render() {
    if (S_ShowWhenUIHidden && !UI::IsOverlayShown())
        DrawUI();
}

void RenderInterface() {
    DrawUI();
}

void RenderMenu() {
    if (!GetPermissionsOkay())
        return;

    if (UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

void Update(float) {
    // checking this every frame has minimal overhead; <0.1ms
    if (!S_SkipMLFeedCheck && S_Enabled)
        CheckMLFeedForBetterTimes();
}

void CheckMLFeedForBetterTimes() {
    const MLFeed::RaceDataProxy@ raceData = MLFeed::GetRaceData();
    if (raceData is null)
        return;

    bool foundBetter = false;
    for (uint i = 0; i < records.Length; i++) {
        PBTime@ pbTime = records[i];

        const MLFeed::PlayerCpInfo@ player = raceData.GetPlayer(pbTime.name);
        if (player is null || player.bestTime < 1)
            continue;

        if (player.bestTime < int(pbTime.time) || pbTime.time < 1) {
            pbTime.time = player.bestTime;
            pbTime.recordTs = Time::Stamp;
            pbTime.replayUrl = "";
            pbTime.UpdateCachedStrings();
            foundBetter = true;
        }
    }

    if (foundBetter)
        records.SortAsc();
}

void DrawUI() {
    if (
        !GetPermissionsOkay()
        || !S_Enabled
        || SoloModeExitCheck()
        || !GetPlaygroundValidAndEditorNull()
    )
        return;

    int uiFlags = UI::WindowFlags::NoCollapse;
    if (S_LockWhenUIHidden && !UI::IsOverlayShown())
        uiFlags |= UI::WindowFlags::NoInputs;
    bool showTitleBar = S_TitleBarWhenUnlocked && UI::IsOverlayShown();
    if (!showTitleBar)
        uiFlags |= UI::WindowFlags::NoTitleBar;

    UI::SetNextWindowSize(400, 400, UI::Cond::FirstUseEver);

    if (UI::Begin(title, S_Enabled, uiFlags)) {
        if (GetApp().CurrentPlayground is null || GetApp().Editor !is null)
            UI::Text("Not in a map \\$999(or in editor).");
        else if (records.IsEmpty())
            UI::Text(g_CurrentlyLoadingRecords ? "Loading..." : "No records :(");
        else {
            // put everything in a child so buttons work when interface is hidden
            if (UI::BeginChild("##pbs-full-ui", UI::GetContentRegionAvail())) {

                // refresh/loading    #N Players: 22    Your Rank: 19 / 22
                if (S_TopInfo) {
                    UI::AlignTextToFramePadding();
                    vec2 curPos1 = UI::GetCursorPos();
                    if (g_CurrentlyLoadingRecords)
                        UI::Text("Updating...");
                    else {
                        if (UI::Button("Refresh"))
                            startnew(UpdateRecords);
                    }
                    UI::SameLine();
                    UI::SetCursorPos(curPos1 + vec2(80.0f, 0.0f));
                    uint nbPlayers = GetPlayersInServerCount();
                    UI::Text("Your Rank: " + GetLocalPlayersRank() + " / " + nbPlayers);
                    if (S_TopInfoMapName) {
                        UI::SameLine();
                        UI::SetCursorPos(curPos1 + vec2(220.0f, 0.0f));
                        UI::Text(MakeColorsOkayDarkMode(ColoredString(GetApp().RootMap.MapName)));
                    }
                }

                if (UI::BeginChild("##pb-table", UI::GetContentRegionAvail())) {
                    uint nbCols = 3; // rank, player and pb time are mandatory
                    if (S_Clubs)
                        nbCols += 1;
                    if (S_Dates)
                        nbCols += 1;
                    if (S_ShowReplayBtn)
                        nbCols += 1;

                    if (UI::BeginTable("local-players-records", nbCols, UI::TableFlags::SizingStretchProp | UI::TableFlags::RowBg)) {
                        UI::TableSetupColumn("");  // rank
                        if (S_Clubs)
                            UI::TableSetupColumn("Club");
                        UI::TableSetupColumn("Player");
                        UI::TableSetupColumn("PB Time");
                        if (S_Dates)
                            UI::TableSetupColumn("PB Date");
                        if (S_ShowReplayBtn)
                            UI::TableSetupColumn("Replay");
                        UI::TableHeadersRow();

                        UI::ListClipper clipper(records.Length);
                        while (clipper.Step()) {
                            for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                                PBTime@ pb = records[i];
                                UI::TableNextRow();

                                // highlight if updated -- note: record timestamps can appear in the future, so we just clamp and wait. // pb.recordTs <= Time::Stamp
                                bool shouldHighlight = S_ShowRecentPBsInGreen && pb.recordTs + 60 > uint(Time::Stamp);
                                if (shouldHighlight) {
                                    const float hlAmount = 1.0f - Math::Clamp(float(int(Time::Stamp) - int(pb.recordTs)) / 60.0f, 0.0f, 1.0f);
                                    UI::PushStyleColor(UI::Col::Text, vec4(0.3f, 0.9f, 0.1f, 1.0f) * hlAmount + vec4(1.0f, 1.0f, 1.0f, 1.0f) * (1.0f - hlAmount));
                                }

                                UI::TableNextColumn();
                                UI::Text(tostring(i + 1) + ".");

                                if (S_Clubs) {
                                    UI::TableNextColumn();
                                    // 0.07 ms overhead for MakeColorsOkayDarkMode for 16 players
                                    if (pb.club.Length > 0)
                                        UI::Text(MakeColorsOkayDarkMode(ColoredString(pb.club)));
                                    // UI::Text(ColoredString(pb.club));
                                }

                                UI::TableNextColumn();
                                UI::Text(pb.name);

                                UI::TableNextColumn();
                                UI::Text(pb.timeStr);

                                if (S_Dates) {
                                    UI::TableNextColumn();
                                    UI::Text(pb.recordDate);
                                }

                                if (S_ShowReplayBtn) {
                                    UI::TableNextColumn();
                                    if (pb.replayUrl.Length > 0 && UI::Button(Icons::FloppyO + "##replay"+ pb.wsid))
                                        OpenBrowserURL(pb.replayUrl);
                                }

                                if (shouldHighlight)
                                    UI::PopStyleColor();
                            }
                        }

                        UI::EndTable();
                    }
                }

                UI::EndChild();
            }

            UI::EndChild();
        }
    }

    UI::End();
}

// fast enough to call once per frame
uint GetLocalPlayersRank() {
    // once per frame
    if (lastLPR_Time + 5 > Time::Now)
        return lastLPR_Rank;

    // otherwise update
    lastLPR_Time = Time::Now;
    lastLPR_Rank = records.Length;

    for (uint i = 0; i < records.Length; i++) {
        if (records[i].isLocalPlayer) {
            lastLPR_Rank = i + 1;
            break;
        }
    }

    return lastLPR_Rank;
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

void NotifyMissingPermissions() {
    UI::ShowNotification(
        title,
        "Missing permissions! D:\nYou probably don't have permission to view records/PBs.\nThis plugin won't do anything.",
        vec4(1.0f, 0.4f, 0.1f, 0.3f),
        10000
    );
    warn("Missing permissions! D:\nYou probably don't have permission to view records/PBs.\nThis plugin won't do anything.");
}

void RetryRecordsSoon() {
    sleep(500);
    UpdateRecords();
}

// returns true if should exit because we're in solo mode
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
    uint   time          = 0;
    string timeStr;
    string recordDate;
    uint   recordTs      = 0;
    string replayUrl;
    string wsid;

    PBTime(CSmPlayer@ _player, CMapRecord@ Record, bool localPlayer = false) {
        wsid = _player.User.WebServicesUserId;  // rare null pointer exception here? `Invalid address for member ID 03002000. This is likely a Nadeo bug! Setting it to null!`
        name = _player.User.Name;
        club = _player.User.ClubTag;
        isLocalPlayer = localPlayer;

        if (Record !is null) {
            recordTs  = Record.Timestamp;
            replayUrl = Record.ReplayUrl;
            time      = Record.Time;
        }

        UpdateCachedStrings();
    }

    void UpdateCachedStrings() {
        recordDate = recordTs > 0 ? Time::FormatString("%m-%d %H:%M", recordTs) : "";
        timeStr    = time > 0 ? Time::Format(time) : "";
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
