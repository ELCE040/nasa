<?php
require_once __DIR__.'/auth.php';
requireAuth();
$pageTitle = 'Matches';
$pdo = db();

try {
    $matchCols = $pdo->query('SHOW COLUMNS FROM matches')->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('isPrivate', $matchCols, true)) {
        $pdo->exec('ALTER TABLE matches ADD COLUMN isPrivate TINYINT(1) NOT NULL DEFAULT 0');
    }
    if (!in_array('playerOfMatchId', $matchCols, true)) {
      $pdo->exec('ALTER TABLE matches ADD COLUMN playerOfMatchId VARCHAR(50) NULL');
    }
    if (!in_array('playerOfMatchName', $matchCols, true)) {
      $pdo->exec('ALTER TABLE matches ADD COLUMN playerOfMatchName VARCHAR(255) NULL');
    }
} catch (PDOException $e) {}

try {
    $teamCols = $pdo->query('SHOW COLUMNS FROM teams')->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('isExternal', $teamCols, true)) {
        $pdo->exec('ALTER TABLE teams ADD COLUMN isExternal TINYINT(1) NOT NULL DEFAULT 0');
    }
    if (!in_array('dashboardOnly', $teamCols, true)) {
        $pdo->exec('ALTER TABLE teams ADD COLUMN dashboardOnly TINYINT(1) NOT NULL DEFAULT 0');
    }
} catch (PDOException $e) {}

$action = $_GET['action'] ?? 'list';
$id     = $_GET['id'] ?? '';

$officialLeagueId = getOfficialLeagueId();
$officialLeagueName = getOfficialLeagueName();

if (isOfficial() && $officialLeagueId) {
    try {
        $teams = $pdo->query('SELECT id,name,wardName,IFNULL(isExternal,0) AS isExternal,IFNULL(dashboardOnly,0) AS dashboardOnly,leagueId FROM teams ORDER BY name')->fetchAll();
    } catch (PDOException $e) {
        $teams = $pdo->query('SELECT id,name,wardName,leagueId FROM teams ORDER BY name')->fetchAll();
    }

    $stmt = $pdo->prepare('SELECT * FROM leagues WHERE id = ? ORDER BY name');
    $stmt->execute([$officialLeagueId]);
    $leagues = $stmt->fetchAll();
} else {
    try {
        $teams = $pdo->query('SELECT id,name,wardName,IFNULL(isExternal,0) AS isExternal,IFNULL(dashboardOnly,0) AS dashboardOnly,leagueId FROM teams ORDER BY name')->fetchAll();
    } catch (PDOException $e) {
        $teams = $pdo->query('SELECT id,name,wardName,leagueId FROM teams ORDER BY name')->fetchAll();
    }
    $leagues = $pdo->query('SELECT * FROM leagues ORDER BY name')->fetchAll();
}

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';
    
    if (isOfficial() && $officialLeagueId) {
        $targetLeagueId = $officialLeagueId;
        $targetLeagueName = $officialLeagueName;
    } else {
        $targetLeagueId = $_POST['leagueId'] ?: null;
        $targetLeagueName = $_POST['leagueName'] ?: null;
    }

    $stage = $_POST['stage'] ?: 'League Match';
    $groupName = $_POST['groupName'] ?: null;
    $comp = trim($_POST['competition'] ?? '');
    if ((empty($comp) || $comp === 'NAYSA League') && !empty($targetLeagueName)) {
        $comp = $targetLeagueName;
    }

    if ($op==='create') {
        $nid = 'm'.uniqid();

        // ── On-the-fly External Opponent creation ────────────────────────────
        // If the admin typed a new external opponent name instead of picking an
        // existing team, create the team record now and use its ID.
        foreach (['home', 'away'] as $side) {
            $quickName = trim($_POST[$side . 'QuickExtName'] ?? '');
            if ($quickName !== '') {
                // Check if a team with this name already exists
                $existing = $pdo->prepare("SELECT id FROM teams WHERE LOWER(TRIM(name))=LOWER(TRIM(?)) LIMIT 1");
                $existing->execute([$quickName]);
                $existingId = $existing->fetchColumn();
                if ($existingId) {
                    $_POST[$side . 'TeamId'] = $existingId;
                } else {
                    $newTeamId = 't' . uniqid();
                    $pdo->prepare("INSERT INTO teams (id, name, coachName, wardName, isExternal, dashboardOnly) VALUES (?,?,?,?,1,1)")
                        ->execute([$newTeamId, $quickName, 'External Opponent', '']);
                    $_POST[$side . 'TeamId'] = $newTeamId;
                }
            }
        }

        $home = array_filter($teams, fn($t) => $t['id']===$_POST['homeTeamId']);
        $away = array_filter($teams, fn($t) => $t['id']===$_POST['awayTeamId']);
        $home = array_values($home)[0] ?? [];
        $away = array_values($away)[0] ?? [];

        // If team was just created on-the-fly it won't be in $teams array yet; fetch it
        if (empty($home) && !empty($_POST['homeTeamId'])) {
            $s = $pdo->prepare("SELECT id,name,wardName,IFNULL(isExternal,0) AS isExternal,IFNULL(dashboardOnly,0) AS dashboardOnly FROM teams WHERE id=?");
            $s->execute([$_POST['homeTeamId']]); $home = $s->fetch() ?: [];
        }
        if (empty($away) && !empty($_POST['awayTeamId'])) {
            $s = $pdo->prepare("SELECT id,name,wardName,IFNULL(isExternal,0) AS isExternal,IFNULL(dashboardOnly,0) AS dashboardOnly FROM teams WHERE id=?");
            $s->execute([$_POST['awayTeamId']]); $away = $s->fetch() ?: [];
        }

        $isPrivate = isset($_POST['isPrivate'])
            ? ((int)$_POST['isPrivate'] === 1 ? 1 : 0)
            : ((!empty($home['isExternal']) || !empty($away['isExternal']) || !empty($home['dashboardOnly']) || !empty($away['dashboardOnly'])) ? 1 : 0);

        $pdo->prepare('INSERT INTO matches (id,homeTeamId,awayTeamId,homeTeamName,awayTeamName,venue,wardName,competition,leagueId,leagueName,kickoff,status,travelDistanceKm,stage,groupName,isPrivate) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)')
          ->execute([$nid,$_POST['homeTeamId'],$_POST['awayTeamId'],$home['name']??'',$away['name']??'',
                 $_POST['venue'],$home['wardName']??'',$comp,$targetLeagueId,$targetLeagueName,
                 $_POST['kickoff']?:null,$_POST['status']??'upcoming',(float)($_POST['travelDistanceKm']??0),
                 $stage, $groupName, $isPrivate]);

        if (!empty($targetLeagueId)) {
            foreach ([$_POST['homeTeamId'], $_POST['awayTeamId']] as $tid) {
                if (!empty($tid)) {
                    try {
                        $pdo->prepare("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
                            VALUES (?, ?, ?, 'participant', NOW())")
                            ->execute(['tc_'.$tid.'_'.$targetLeagueId, $tid, $targetLeagueId]);
                    } catch (Throwable $e) {}
                }
            }
        }

        flash('success','Match scheduled!');
        header('Location: matches.php'); exit;
    }
    if ($op==='update') {
        if (isOfficial() && $officialLeagueId) {
            $chk = $pdo->prepare('SELECT leagueId FROM matches WHERE id=?');
            $chk->execute([$_POST['id']]);
            if ($chk->fetchColumn() !== $officialLeagueId) {
                flash('error', 'Unauthorized match update.');
                header('Location: matches.php'); exit;
            }
        }
        $isPrivate = (int)($_POST['isPrivate'] ?? 0) === 1 ? 1 : 0;
        $playerOfMatchId = (($_POST['status'] ?? '') === 'fullTime') ? trim($_POST['playerOfMatchId'] ?? '') : '';
        $playerOfMatchName = null;
        if ($playerOfMatchId !== '') {
            $playerStmt = $pdo->prepare('SELECT name FROM players WHERE id=? AND teamId IN (SELECT homeTeamId FROM matches WHERE id=? UNION SELECT awayTeamId FROM matches WHERE id=?) LIMIT 1');
            $playerStmt->execute([$playerOfMatchId, $_POST['id'], $_POST['id']]);
            $playerOfMatchName = $playerStmt->fetchColumn() ?: null;
        }
        $pdo->prepare('UPDATE matches SET status=?,homeScore=?,awayScore=?,venue=?,competition=?,leagueId=?,leagueName=?,kickoff=?,stage=?,groupName=?,isPrivate=?,playerOfMatchId=?,playerOfMatchName=? WHERE id=?')
          ->execute([$_POST['status'],(int)($_POST['homeScore']??0),(int)($_POST['awayScore']??0),
                 $_POST['venue'],$comp,$targetLeagueId,$targetLeagueName,$_POST['kickoff']?:null,
                 $stage,$groupName,$isPrivate,$playerOfMatchId ?: null,$playerOfMatchName,$_POST['id']]);

        if (!empty($targetLeagueId)) {
            $mTeams = $pdo->prepare("SELECT homeTeamId, awayTeamId FROM matches WHERE id=?");
            $mTeams->execute([$_POST['id']]);
            $mt = $mTeams->fetch();
            if ($mt) {
                foreach ([$mt['homeTeamId'], $mt['awayTeamId']] as $tid) {
                    if (!empty($tid)) {
                        try {
                            $pdo->prepare("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
                                VALUES (?, ?, ?, 'participant', NOW())")
                                ->execute(['tc_'.$tid.'_'.$targetLeagueId, $tid, $targetLeagueId]);
                        } catch (Throwable $e) {}
                    }
                }
            }
        }

        if (($_POST['status'] ?? '') === 'fullTime') {
            try {
                $stageFlow = [
                    'Round of 32'   => 'Round of 16',
                    'Round of 16'   => 'Quarter-Final',
                    'Quarter-Final' => 'Semi-Final',
                    'Semi-Final'    => 'Final',
                ];
                if (isset($stageFlow[$stage]) && $targetLeagueId) {
                    $nextStage = $stageFlow[$stage];
                    $stmt = $pdo->prepare("SELECT * FROM matches WHERE leagueId=? AND stage=? ORDER BY id ASC");
                    $stmt->execute([$targetLeagueId, $stage]);
                    $stageMatches = $stmt->fetchAll();
                    $matchIndex = -1;
                    foreach ($stageMatches as $i => $sm) {
                        if ($sm['id'] === $_POST['id']) { $matchIndex = $i; break; }
                    }
                    if ($matchIndex !== -1) {
                        $pairIndex  = (int)floor($matchIndex / 2);
                        $isHomeSlot = ($matchIndex % 2 === 0);
                        $partnerIdx = $isHomeSlot ? $matchIndex + 1 : $matchIndex - 1;
                        $hScore     = (int)($_POST['homeScore'] ?? 0);
                        $aScore     = (int)($_POST['awayScore'] ?? 0);

                        $currMatchStmt = $pdo->prepare("SELECT * FROM matches WHERE id=?");
                        $currMatchStmt->execute([$_POST['id']]);
                        $cm = $currMatchStmt->fetch();

                        // A tied knockout match advances only after its recorded
                        // shootout result. Shootout goals never alter match goals.
                        $homeWon = $hScore > $aScore;
                        if ($hScore === $aScore) {
                            $shootoutStmt = $pdo->prepare("SELECT teamName, COUNT(*) AS total FROM match_events WHERE matchId=? AND type='Shootout Goal' GROUP BY teamName");
                            $shootoutStmt->execute([$_POST['id']]);
                            $shootout = ['home' => 0, 'away' => 0];
                            foreach ($shootoutStmt->fetchAll() as $row) {
                                if ($row['teamName'] === $cm['homeTeamName']) $shootout['home'] = (int)$row['total'];
                                if ($row['teamName'] === $cm['awayTeamName']) $shootout['away'] = (int)$row['total'];
                            }
                            // Do not advance a drawn knockout fixture until a winner exists.
                            if ($shootout['home'] === $shootout['away']) {
                                flash('error', 'A tied knockout match needs a penalty shootout winner before it can advance.');
                                header('Location: matches.php'); exit;
                            }
                            $homeWon = $shootout['home'] > $shootout['away'];
                        }
                        $winnerCurrent = $homeWon ? [
                            'id' => $cm['homeTeamId'], 'name' => $cm['homeTeamName'], 'ward' => $cm['wardName'] ?? ''
                        ] : [
                            'id' => $cm['awayTeamId'], 'name' => $cm['awayTeamName'], 'ward' => $cm['wardName'] ?? ''
                        ];

                        $stmt = $pdo->prepare("SELECT * FROM matches WHERE leagueId=? AND stage=? ORDER BY id ASC");
                        $stmt->execute([$targetLeagueId, $nextStage]);
                        $nextMatches = $stmt->fetchAll();

                        if (isset($nextMatches[$pairIndex])) {
                            // Next-round fixture already exists: only update our slot
                            $existingNext = $nextMatches[$pairIndex];
                            if ($isHomeSlot) {
                                $pdo->prepare("UPDATE matches SET homeTeamId=?, homeTeamName=? WHERE id=?")
                                    ->execute([$winnerCurrent['id'], $winnerCurrent['name'], $existingNext['id']]);
                            } else {
                                $pdo->prepare("UPDATE matches SET awayTeamId=?, awayTeamName=? WHERE id=?")
                                    ->execute([$winnerCurrent['id'], $winnerCurrent['name'], $existingNext['id']]);
                            }
                        } else {
                            // No next-round fixture yet — create one immediately
                            $partnerMatch  = $stageMatches[$partnerIdx] ?? null;
                            $winnerPartner = null;
                            if ($partnerMatch && $partnerMatch['status'] === 'fullTime') {
                                $winnerPartner = ($partnerMatch['homeScore'] > $partnerMatch['awayScore']) ? [
                                    'id' => $partnerMatch['homeTeamId'], 'name' => $partnerMatch['homeTeamName'], 'ward' => $partnerMatch['wardName'] ?? ''
                                ] : [
                                    'id' => $partnerMatch['awayTeamId'], 'name' => $partnerMatch['awayTeamName'], 'ward' => $partnerMatch['wardName'] ?? ''
                                ];
                            }

                            $newId   = 'm' . uniqid();
                            $venue   = !empty($cm['venue']) ? $cm['venue'] : 'Tournament Main Arena';
                            $kickoff = date('Y-m-d H:i:s', strtotime('+3 days 15:00:00'));

                            if ($winnerPartner) {
                                // Both teams known
                                $homeId   = $isHomeSlot ? $winnerCurrent['id']   : $winnerPartner['id'];
                                $homeName = $isHomeSlot ? $winnerCurrent['name'] : $winnerPartner['name'];
                                $awayId   = $isHomeSlot ? $winnerPartner['id']   : $winnerCurrent['id'];
                                $awayName = $isHomeSlot ? $winnerPartner['name'] : $winnerCurrent['name'];
                            } else {
                                // Only this team is ready — opponent TBD
                                $homeId   = $isHomeSlot ? $winnerCurrent['id']   : 'tbd';
                                $homeName = $isHomeSlot ? $winnerCurrent['name'] : 'TBD (Awaiting Opponent)';
                                $awayId   = $isHomeSlot ? 'tbd'                  : $winnerCurrent['id'];
                                $awayName = $isHomeSlot ? 'TBD (Awaiting Opponent)' : $winnerCurrent['name'];
                            }

                            $pdo->prepare("INSERT INTO matches (id, homeTeamId, awayTeamId, homeTeamName, awayTeamName, venue, wardName, competition, leagueId, leagueName, kickoff, status, stage) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)")
                                ->execute([
                                    $newId, $homeId, $awayId, $homeName, $awayName,
                                    $venue, $winnerCurrent['ward'], $comp,
                                    $targetLeagueId, $targetLeagueName, $kickoff, 'upcoming', $nextStage
                                ]);
                        }
                    }
                }
            } catch (Exception $e) {
                // Ignore error in background progression
            }
        }

        flash('success','Match updated!');
        header('Location: matches.php'); exit;
    }
    if ($op==='delete') {
        if (isOfficial() && $officialLeagueId) {
            $chk = $pdo->prepare('SELECT leagueId FROM matches WHERE id=?');
            $chk->execute([$_POST['id']]);
            if ($chk->fetchColumn() !== $officialLeagueId) {
                flash('error', 'Unauthorized match delete.');
                header('Location: matches.php'); exit;
            }
        }
        $pdo->prepare('DELETE FROM matches WHERE id=?')->execute([$_POST['id']]);
        flash('success','Match deleted.');
        header('Location: matches.php'); exit;
    }
}

if ($action==='edit' && $id) {
    if (isOfficial() && $officialLeagueId) {
        $match = $pdo->prepare('SELECT * FROM matches WHERE id=? AND leagueId=?');
        $match->execute([$id, $officialLeagueId]);
    } else {
        $match = $pdo->prepare('SELECT * FROM matches WHERE id=?');
        $match->execute([$id]);
    }
    $match = $match->fetch();
}

  $matchPlayers = [];
  if ($action === 'edit' && !empty($match)) {
    $playerStmt = $pdo->prepare('SELECT id, name, teamId FROM players WHERE teamId IN (?, ?) ORDER BY teamId, name');
    $playerStmt->execute([$match['homeTeamId'], $match['awayTeamId']]);
    $matchPlayers = $playerStmt->fetchAll();
  }

// Fetch list of matches
if (isOfficial() && $officialLeagueId) {
    $stmt = $pdo->prepare('SELECT * FROM matches WHERE leagueId=? ORDER BY kickoff DESC');
    $stmt->execute([$officialLeagueId]);
    $matchesList = $stmt->fetchAll();
} else {
    $matchesList = $pdo->query('SELECT * FROM matches ORDER BY kickoff DESC')->fetchAll();
}

$statuses = ['upcoming','live','fullTime','postponed'];
$stages = ['League Match','Group Stage','Round of 32','Round of 16','Quarter-Final','Semi-Final','Third Place','Final'];
require __DIR__.'/header.php';
?>
<?php if ($action==='add'): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Schedule New Match</span><a href="matches.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <!-- HOME TEAM -->
      <div class="form-group">
        <label>Home Team *</label>
        <div id="homeTeamMode" style="display:flex;gap:8px;margin-bottom:6px;">
          <button type="button" onclick="setTeamMode('home','existing')" id="homeModeExistingBtn"
            style="flex:1;padding:6px;border-radius:6px;border:1px solid var(--gold);background:rgba(210,176,89,.15);color:var(--gold);font-size:12px;font-weight:700;cursor:pointer;">
            Select Existing Team
          </button>
          <button type="button" onclick="setTeamMode('home','new')" id="homeModeNewBtn"
            style="flex:1;padding:6px;border-radius:6px;border:1px solid #1A3A5C;background:transparent;color:#8BA3B8;font-size:12px;font-weight:700;cursor:pointer;">
            + New External Opponent
          </button>
        </div>
        <div id="homeExistingWrap">
          <select name="homeTeamId" id="homeTeamId" onchange="checkMatchPrivacy()">
            <option value="">Select existing team...</option>
            <?php foreach($teams as $t): ?>
              <option value="<?= e($t['id']) ?>" data-ext="<?= (!empty($t['isExternal']) || !empty($t['dashboardOnly'])) ? '1' : '0' ?>">
                <?= e($t['name']) ?><?= !empty($t['isExternal']) ? ' [External]' : (!empty($t['dashboardOnly']) ? ' [Private]' : '') ?>
              </option>
            <?php endforeach; ?>
          </select>
        </div>
        <div id="homeNewWrap" style="display:none;">
          <input type="text" name="homeQuickExtName" id="homeQuickExtName"
            placeholder="Type external opponent name (e.g. St. Mary's FC)"
            oninput="onQuickExtInput('home')" />
          <small style="color:#f59e0b;display:block;margin-top:4px;">
            A new External Opponent team record will be created automatically. Match will be set to Private.
          </small>
        </div>
      </div>

      <!-- AWAY TEAM -->
      <div class="form-group">
        <label>Away Team *</label>
        <div id="awayTeamMode" style="display:flex;gap:8px;margin-bottom:6px;">
          <button type="button" onclick="setTeamMode('away','existing')" id="awayModeExistingBtn"
            style="flex:1;padding:6px;border-radius:6px;border:1px solid var(--gold);background:rgba(210,176,89,.15);color:var(--gold);font-size:12px;font-weight:700;cursor:pointer;">
            Select Existing Team
          </button>
          <button type="button" onclick="setTeamMode('away','new')" id="awayModeNewBtn"
            style="flex:1;padding:6px;border-radius:6px;border:1px solid #1A3A5C;background:transparent;color:#8BA3B8;font-size:12px;font-weight:700;cursor:pointer;">
            + New External Opponent
          </button>
        </div>
        <div id="awayExistingWrap">
          <select name="awayTeamId" id="awayTeamId" onchange="checkMatchPrivacy()">
            <option value="">Select existing team...</option>
            <?php foreach($teams as $t): ?>
              <option value="<?= e($t['id']) ?>" data-ext="<?= (!empty($t['isExternal']) || !empty($t['dashboardOnly'])) ? '1' : '0' ?>">
                <?= e($t['name']) ?><?= !empty($t['isExternal']) ? ' [External]' : (!empty($t['dashboardOnly']) ? ' [Private]' : '') ?>
              </option>
            <?php endforeach; ?>
          </select>
        </div>
        <div id="awayNewWrap" style="display:none;">
          <input type="text" name="awayQuickExtName" id="awayQuickExtName"
            placeholder="Type external opponent name (e.g. St. Mary's FC)"
            oninput="onQuickExtInput('away')" />
          <small style="color:#f59e0b;display:block;margin-top:4px;">
            A new External Opponent team record will be created automatically. Match will be set to Private.
          </small>
        </div>
      </div>
      <div class="form-group"><label>Match Visibility</label>
        <select name="isPrivate" id="matchIsPrivateSelect">
          <option value="0">Public in app (NAYSA league standings)</option>
          <option value="1">Private / External Match (Dashboard only, does not alter NAYSA standings)</option>
        </select>
        <small style="color:#8BA3B8">Private matches with external opponents are dashboard-only and do not affect NAYSA public standings.</small>
      </div>
      <div class="form-group"><label>Venue</label><input name="venue"/></div>
      <div class="form-group"><label>Competition</label><input name="competition" id="competitionInput" value="<?= e($officialLeagueName ?? 'NAYSA League') ?>"/></div>
      <div class="form-group"><label>League / Tournament</label>
        <?php if (isOfficial() && $officialLeagueId): ?>
            <input type="text" readonly value="<?= e($officialLeagueName) ?>" style="background:rgba(255,255,255,0.05); color:var(--gold);" />
            <input type="hidden" name="leagueId" value="<?= e($officialLeagueId) ?>"/>
            <input type="hidden" name="leagueName" value="<?= e($officialLeagueName) ?>"/>
        <?php else: ?>
            <select name="leagueId" onchange="const txt=this.options[this.selectedIndex].text; this.form.querySelector('[name=leagueName]').value=(this.value?txt:''); if(this.value){ document.getElementById('competitionInput').value=txt; }">
              <option value="">(None)</option>
              <?php foreach($leagues as $L): ?>
              <option value="<?= e($L['id']) ?>"><?= e($L['name']) ?></option>
              <?php endforeach; ?>
            </select>
            <input type="hidden" name="leagueName" value=""/>
        <?php endif; ?>
      </div>
      <div class="form-group"><label>Stage / Round</label>
        <select name="stage">
          <?php foreach($stages as $stg): ?>
          <option value="<?= $stg ?>"><?= $stg ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="form-group"><label>Group (Optional)</label>
        <input name="groupName" placeholder="e.g. Group A, Group B"/>
      </div>
      <div class="form-group"><label>Kick-off Date & Time</label><input type="datetime-local" name="kickoff"/></div>
      <div class="form-group"><label>Status</label>
        <select name="status"><?php foreach($statuses as $s): ?><option><?= $s ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Travel Distance (km)</label><input type="number" step="0.1" name="travelDistanceKm" value="0"/></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">sports_soccer</span>Schedule Match</button>
      <a href="matches.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
  <script>
  function setTeamMode(side, mode) {
    const isNew = mode === 'new';
    document.getElementById(side + 'ExistingWrap').style.display = isNew ? 'none' : 'block';
    document.getElementById(side + 'NewWrap').style.display = isNew ? 'block' : 'none';

    const existBtn = document.getElementById(side + 'ModeExistingBtn');
    const newBtn = document.getElementById(side + 'ModeNewBtn');
    if (isNew) {
      existBtn.style.borderColor = '#1A3A5C';
      existBtn.style.background = 'transparent';
      existBtn.style.color = '#8BA3B8';

      newBtn.style.borderColor = 'var(--gold)';
      newBtn.style.background = 'rgba(210,176,89,.15)';
      newBtn.style.color = 'var(--gold)';

      // Clear select selection
      const sel = document.getElementById(side + 'TeamId');
      if (sel) sel.value = '';

      // Auto-set match privacy to Private
      const pSel = document.getElementById('matchIsPrivateSelect');
      if (pSel) pSel.value = '1';

      // Focus text input
      const inp = document.getElementById(side + 'QuickExtName');
      if (inp) inp.focus();
    } else {
      existBtn.style.borderColor = 'var(--gold)';
      existBtn.style.background = 'rgba(210,176,89,.15)';
      existBtn.style.color = 'var(--gold)';

      newBtn.style.borderColor = '#1A3A5C';
      newBtn.style.background = 'transparent';
      newBtn.style.color = '#8BA3B8';

      // Clear text input
      const inp = document.getElementById(side + 'QuickExtName');
      if (inp) inp.value = '';

      checkMatchPrivacy();
    }
  }

  function onQuickExtInput(side) {
    const val = (document.getElementById(side + 'QuickExtName').value || '').trim();
    if (val.length > 0) {
      const pSel = document.getElementById('matchIsPrivateSelect');
      if (pSel) pSel.value = '1';
    }
  }

  function checkMatchPrivacy() {
    const h = document.getElementById('homeTeamId');
    const a = document.getElementById('awayTeamId');
    const hOpt = h && h.selectedIndex >= 0 ? h.options[h.selectedIndex] : null;
    const aOpt = a && a.selectedIndex >= 0 ? a.options[a.selectedIndex] : null;
    const hExtText = (document.getElementById('homeQuickExtName')?.value || '').trim();
    const aExtText = (document.getElementById('awayQuickExtName')?.value || '').trim();

    const isExt = (hOpt && hOpt.dataset.ext === '1') || 
                  (aOpt && aOpt.dataset.ext === '1') || 
                  hExtText.length > 0 || 
                  aExtText.length > 0;

    const pSel = document.getElementById('matchIsPrivateSelect');
    if (pSel && isExt) pSel.value = '1';
  }

  // Validate form submission to ensure both teams are provided
  document.querySelector('form[method="post"]')?.addEventListener('submit', function(e) {
    if (this.querySelector('input[name="op"]')?.value !== 'create') return;

    const hSel = (document.getElementById('homeTeamId')?.value || '').trim();
    const hTxt = (document.getElementById('homeQuickExtName')?.value || '').trim();
    if (!hSel && !hTxt) {
      e.preventDefault();
      alert('Please select or type a Home Team.');
      return false;
    }

    const aSel = (document.getElementById('awayTeamId')?.value || '').trim();
    const aTxt = (document.getElementById('awayQuickExtName')?.value || '').trim();
    if (!aSel && !aTxt) {
      e.preventDefault();
      alert('Please select or type an Away Team.');
      return false;
    }

    if ((hSel && aSel && hSel === aSel) || (hTxt && aTxt && hTxt.toLowerCase() === aTxt.toLowerCase())) {
      e.preventDefault();
      alert('Home and Away teams must be different.');
      return false;
    }
  });
  </script>
</div>

<?php elseif ($action==='edit' && isset($match)): ?>
<div class="card">
  <div class="section-header"><span class="section-title"><?= e($match['homeTeamName']) ?> vs <?= e($match['awayTeamName']) ?></span><a href="matches.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post" action="matches.php">
    <input type="hidden" name="op" value="update"/>
    <input type="hidden" name="id" value="<?= e($match['id']) ?>"/>
    <div class="form-grid">
      <div class="form-group"><label>Status</label>
        <select name="status" id="matchStatus" onchange="togglePlayerOfMatch()">
          <?php foreach($statuses as $s): ?><option <?= $match['status']===$s?'selected':'' ?>><?= $s ?></option><?php endforeach; ?>
        </select>
      </div>
      <div class="form-group"><label>Match Visibility</label>
        <select name="isPrivate">
          <option value="0" <?= empty($match['isPrivate'])?'selected':'' ?>>Public in app (NAYSA league standings)</option>
          <option value="1" <?= !empty($match['isPrivate'])?'selected':'' ?>>Private / External Match (Dashboard only, does not alter NAYSA standings)</option>
        </select>
        <small style="color:#8BA3B8">Private matches with external opponents do not alter public NAYSA standings.</small>
      </div>
      <div class="form-group"><label>Home Score</label><input type="number" name="homeScore" value="<?= e($match['homeScore']??0) ?>"/></div>
      <div class="form-group"><label>Away Score</label><input type="number" name="awayScore" value="<?= e($match['awayScore']??0) ?>"/></div>
      <div class="form-group"><label>Stage / Round</label>
        <select name="stage">
          <?php foreach($stages as $stg): ?>
          <option value="<?= $stg ?>" <?= ($match['stage']??'League Match')===$stg?'selected':'' ?>><?= $stg ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="form-group"><label>Group (Optional)</label>
        <input name="groupName" value="<?= e($match['groupName']??'') ?>" placeholder="e.g. Group A, Group B"/>
      </div>
      <div class="form-group"><label>Venue</label><input name="venue" value="<?= e($match['venue']) ?>"/></div>
      <div class="form-group"><label>Competition</label><input name="competition" value="<?= e($match['competition']) ?>"/></div>
      <div class="form-group"><label>League / Tournament</label>
        <?php if (isOfficial() && $officialLeagueId): ?>
            <input type="text" readonly value="<?= e($officialLeagueName) ?>" style="background:rgba(255,255,255,0.05); color:var(--gold);" />
            <input type="hidden" name="leagueId" value="<?= e($officialLeagueId) ?>"/>
            <input type="hidden" name="leagueName" value="<?= e($officialLeagueName) ?>"/>
        <?php else: ?>
            <select name="leagueId" onchange="this.form.querySelector('[name=leagueName]').value=this.options[this.selectedIndex].text">
              <option value="">(None)</option>
              <?php foreach($leagues as $L): ?>
              <option value="<?= e($L['id']) ?>" <?= ($match['leagueId']??'')===$L['id']?'selected':'' ?>><?= e($L['name']) ?></option>
              <?php endforeach; ?>
            </select>
            <input type="hidden" name="leagueName" value="<?= e($match['leagueName']??'') ?>"/>
        <?php endif; ?>
      </div>
      <div class="form-group"><label>Kick-off</label><input type="datetime-local" name="kickoff" value="<?= $match['kickoff'] ? date('Y-m-d\TH:i', strtotime($match['kickoff'])) : '' ?>"/></div>
      <div class="form-group" style="grid-column:1/-1;"><label>⭐ Player of the Match</label>
        <select name="playerOfMatchId" id="playerOfMatchId" <?= ($match['status']??'') !== 'fullTime' ? 'disabled' : '' ?>>
          <option value="">Select after the match is full time</option>
          <?php foreach ($matchPlayers as $player): ?>
          <option value="<?= e($player['id']) ?>" <?= ($match['playerOfMatchId']??'') === $player['id'] ? 'selected' : '' ?>><?= e($player['name']) ?> (<?= $player['teamId'] === $match['homeTeamId'] ? 'Home' : 'Away' ?>)</option>
          <?php endforeach; ?>
        </select>
        <small style="color:#8BA3B9">Choose one player after setting the match status to fullTime.</small>
      </div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit">Update Match</button>
      <a href="matches.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>
<script>
function togglePlayerOfMatch() {
  const status = document.getElementById('matchStatus');
  const award = document.getElementById('playerOfMatchId');
  if (status && award) award.disabled = status.value !== 'fullTime';
}
</script>

<?php else: ?>
<div class="section-header">
  <span class="section-title">
    Matches <?= isOfficial() ? '('.e($officialLeagueName).')' : '' ?> (<?= count($matchesList) ?>)
  </span>
  <a href="matches.php?action=add" class="btn btn-gold"><span class="material-icons-round">add</span>Schedule Match</a>
</div>
<div class="card">
  <div class="table-wrap">
  <table>
    <thead><tr><th>Home</th><th>Score</th><th>Away</th><th>Stage / Group</th><th>Competition</th><th>Date</th><th>Status</th><th>Actions</th></tr></thead>
    <tbody>
    <?php foreach($matchesList as $m):
      $badges=['upcoming'=>'badge-blue','live'=>'badge-red','fullTime'=>'badge-gray','postponed'=>'badge-gray'];
      $stg = $m['stage'] ?? 'League Match';
      $grp = !empty($m['groupName']) ? ' (' . e($m['groupName']) . ')' : '';
    ?>
    <tr>
      <td><strong><?= e($m['homeTeamName']) ?></strong></td>
      <td style="text-align:center;font-weight:900;font-size:16px;color:#D2B059"><?= e($m['homeScore']) ?> – <?= e($m['awayScore']) ?></td>
      <td><strong><?= e($m['awayTeamName']) ?></strong></td>
      <td><span class="badge badge-gray"><?= e($stg) . $grp ?></span></td>
      <td>
        <small><?= e($m['competition']) ?></small>
        <?= !empty($m['isPrivate']) ? '<br><span class="badge" style="background:#f59e0b;color:#000;font-size:10px;font-weight:700">Private / External</span>' : '' ?>
      </td>
      <td style="color:#8BA3B8"><small><?= $m['kickoff'] ? date('d M Y H:i', strtotime($m['kickoff'])) : 'TBD' ?></small></td>
      <td><span class="badge <?= $badges[$m['status']]??'badge-gray' ?>"><?= e($m['status']) ?></span></td>
      <td>
        <a href="matches.php?action=edit&id=<?= e($m['id']) ?>" class="btn btn-outline btn-sm"><span class="material-icons-round">edit</span></a>
        <form method="post" style="display:inline" onsubmit="return confirm('Delete match?')">
          <input type="hidden" name="op" value="delete"/>
          <input type="hidden" name="id" value="<?= e($m['id']) ?>"/>
          <button class="btn btn-danger btn-sm" type="submit"><span class="material-icons-round">delete</span></button>
        </form>
      </td>
    </tr>
    <?php endforeach; ?>
    <?php if (empty($matchesList)): ?>
    <tr><td colspan="7" style="text-align:center; padding:20px; color:var(--slate);">No matches scheduled yet.</td></tr>
    <?php endif; ?>
    </tbody>
  </table>
  </div>
</div>
<?php endif; ?>
<?php require __DIR__.'/footer.php'; ?>
