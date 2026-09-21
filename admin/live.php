<?php
require_once __DIR__.'/auth.php';
requireAuth();
$pageTitle = '🔴 Live Match Control';
$pdo = db();

// js() — safely embed a PHP value inside a single-quoted JS string in an HTML attribute
function js(mixed $v): string {
    $s = str_replace(['\\', "'", "\n", "\r"], ['\\\\', "\\'", '', ''], (string)($v ?? ''));
    return htmlspecialchars($s, ENT_COMPAT); // ENT_COMPAT keeps single-quotes as-is
}

function autoEnrolMatchTeams(PDO $pdo, ?string $leagueId, ?string $homeTeamId, ?string $awayTeamId): void {
  if (empty($leagueId)) return;
  foreach ([$homeTeamId, $awayTeamId] as $teamId) {
    if (empty($teamId) || $teamId === 'tbd') continue;
    try {
      $pdo->prepare("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
        VALUES (?, ?, ?, 'participant', NOW())")
        ->execute(['tc_'.$teamId.'_'.$leagueId, $teamId, $leagueId]);
      $pdo->prepare("UPDATE teams SET leagueId=? WHERE id=? AND (leagueId IS NULL OR leagueId='')")
        ->execute([$leagueId, $teamId]);
    } catch (Throwable $e) {}
  }
}

function autoAdvanceKnockoutPhp($pdo, $matchId) {
    try {
        $stmt = $pdo->prepare("SELECT * FROM matches WHERE id=?");
        $stmt->execute([$matchId]);
        $match = $stmt->fetch();
        if (!$match || empty($match['leagueId']) || $match['status'] !== 'fullTime') {
            return ['advanced' => false];
        }

        $stage = $match['stage'] ?? '';
        $stageFlow = [
            'Round of 32'   => 'Round of 16',
            'Round of 16'   => 'Quarter-Final',
            'Quarter-Final' => 'Semi-Final',
            'Semi-Final'    => 'Final',
        ];

        if (!isset($stageFlow[$stage])) {
            return ['advanced' => false];
        }

        $nextStage = $stageFlow[$stage];
        $leagueId = $match['leagueId'];

        $stmt = $pdo->prepare("SELECT * FROM matches WHERE leagueId=? AND stage=? ORDER BY id ASC");
        $stmt->execute([$leagueId, $stage]);
        $stageMatches = $stmt->fetchAll();
        if (empty($stageMatches)) return ['advanced' => false];

        $matchIndex = -1;
        foreach ($stageMatches as $i => $sm) {
            if ($sm['id'] === $matchId) {
                $matchIndex = $i;
                break;
            }
        }
        if ($matchIndex === -1) return ['advanced' => false];

        $pairIndex = (int)floor($matchIndex / 2);
        $isHomeSlot = ($matchIndex % 2 === 0);

        $homeWon = (int)$match['homeScore'] > (int)$match['awayScore'];
        if ((int)$match['homeScore'] === (int)$match['awayScore']) {
            $shootout = shootoutScorePhp($pdo, $matchId, $match['homeTeamName'], $match['awayTeamName']);
            if ($shootout['home'] === $shootout['away']) return ['advanced' => false];
            $homeWon = $shootout['home'] > $shootout['away'];
        }
        $winnerCurrent = $homeWon ? [
            'id' => $match['homeTeamId'],
            'name' => $match['homeTeamName'],
            'ward' => $match['wardName'] ?? ''
        ] : [
            'id' => $match['awayTeamId'],
            'name' => $match['awayTeamName'],
            'ward' => $match['wardName'] ?? ''
        ];

        $stmt = $pdo->prepare("SELECT * FROM matches WHERE leagueId=? AND stage=? ORDER BY id ASC");
        $stmt->execute([$leagueId, $nextStage]);
        $nextMatches = $stmt->fetchAll();

        if (isset($nextMatches[$pairIndex])) {
            $existingNext = $nextMatches[$pairIndex];
            if ($isHomeSlot) {
                $pdo->prepare("UPDATE matches SET homeTeamId=?, homeTeamName=? WHERE id=?")
                    ->execute([$winnerCurrent['id'], $winnerCurrent['name'], $existingNext['id']]);
            } else {
                $pdo->prepare("UPDATE matches SET awayTeamId=?, awayTeamName=? WHERE id=?")
                    ->execute([$winnerCurrent['id'], $winnerCurrent['name'], $existingNext['id']]);
            }
            return ['advanced' => true, 'stage' => $nextStage, 'updatedId' => $existingNext['id']];
        } else {
            $newId = 'm' . uniqid();
            $venue = !empty($match['venue']) ? $match['venue'] : 'Tournament Main Arena';
            $comp = !empty($match['competition']) ? $match['competition'] : $match['leagueName'];
            $kickoff = date('Y-m-d H:i:s', strtotime('+3 days 15:00:00'));

            $homeId = $isHomeSlot ? $winnerCurrent['id'] : 'tbd';
            $homeName = $isHomeSlot ? $winnerCurrent['name'] : 'TBD (Awaiting Opponent)';
            $awayId = $isHomeSlot ? 'tbd' : $winnerCurrent['id'];
            $awayName = $isHomeSlot ? 'TBD (Awaiting Opponent)' : $winnerCurrent['name'];

            $pdo->prepare("INSERT INTO matches (id, homeTeamId, awayTeamId, homeTeamName, awayTeamName, venue, wardName, competition, leagueId, leagueName, kickoff, status, stage) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)")
                ->execute([
                    $newId,
                    $homeId,
                    $awayId,
                    $homeName,
                    $awayName,
                    $venue,
                    $winnerCurrent['ward'],
                    $comp,
                    $leagueId,
                    $match['leagueName'],
                    $kickoff,
                    'upcoming',
                    $nextStage
                ]);
            return ['advanced' => true, 'createdId' => $newId, 'stage' => $nextStage];
        }
    } catch (Exception $e) {
        // Continue silently
    }
    return ['advanced' => false];
}

/** Shootout events are kept separate from the match score and player stats. */
function shootoutScorePhp($pdo, $matchId, $homeTeamName, $awayTeamName) {
    $stmt = $pdo->prepare("SELECT teamName, COUNT(*) AS total FROM match_events WHERE matchId=? AND type='Shootout Goal' GROUP BY teamName");
    $stmt->execute([$matchId]);
    $scores = ['home' => 0, 'away' => 0];
    foreach ($stmt->fetchAll() as $row) {
        if ($row['teamName'] === $homeTeamName) $scores['home'] = (int)$row['total'];
        if ($row['teamName'] === $awayTeamName) $scores['away'] = (int)$row['total'];
    }
    return $scores;
}

// Ensure award columns exist before AJAX requests can use them.
try {
  $cPlayerOfMatch = $pdo->query("SHOW COLUMNS FROM matches LIKE 'playerOfMatchId'")->fetch();
  if (!$cPlayerOfMatch) $pdo->exec("ALTER TABLE matches ADD COLUMN playerOfMatchId VARCHAR(50) NULL");
  $cPlayerOfMatchName = $pdo->query("SHOW COLUMNS FROM matches LIKE 'playerOfMatchName'")->fetch();
  if (!$cPlayerOfMatchName) $pdo->exec("ALTER TABLE matches ADD COLUMN playerOfMatchName VARCHAR(255) NULL");
  $cLiveStartedAt = $pdo->query("SHOW COLUMNS FROM matches LIKE 'liveStartedAt'")->fetch();
  if (!$cLiveStartedAt) $pdo->exec("ALTER TABLE matches ADD COLUMN liveStartedAt DATETIME NULL");
} catch (Exception $e) {
  error_log('Player of Match migration failed: ' . $e->getMessage());
}

// ─── AJAX / POST handler ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json');
    $op  = $_POST['op'] ?? '';
    $id  = $_POST['id'] ?? '';

    $officialLeagueId = getOfficialLeagueId();
    if (isOfficial() && $officialLeagueId && $id) {
        $chk = $pdo->prepare("SELECT leagueId FROM matches WHERE id=?");
        $chk->execute([$id]);
        if ($chk->fetchColumn() !== $officialLeagueId) {
            echo json_encode(['ok'=>false, 'msg'=>'Unauthorized match for your assigned league']);
            exit;
        }
    }

    try {
        if (!empty($id)) {
            $mRow = $pdo->prepare("SELECT homeTeamId, awayTeamId, leagueId FROM matches WHERE id=?");
            $mRow->execute([$id]);
            $mr = $mRow->fetch();
            if ($mr && !empty($mr['leagueId'])) {
                autoEnrolMatchTeams($pdo, $mr['leagueId'], $mr['homeTeamId'], $mr['awayTeamId']);
            }
        }

        if ($op === 'set_live') {
          $pdo->prepare("UPDATE matches SET status='live', minute=0, phase='First Half', liveStartedAt=NOW() WHERE id=?")->execute([$id]);
            echo json_encode(['ok'=>true,'msg'=>'Match set to LIVE']);
        }
        elseif ($op === 'set_status') {
            $s = $_POST['status'] ?? 'upcoming';
          $pdo->prepare("UPDATE matches SET status=?, liveStartedAt=CASE WHEN ?='live' THEN COALESCE(liveStartedAt, NOW()) ELSE NULL END WHERE id=?")
            ->execute([$s, $s, $id]);
            if ($s === 'fullTime') {
                autoAdvanceKnockoutPhp($pdo, $id);
            $playerStmt = $pdo->prepare('SELECT id, name, teamId FROM players WHERE teamId IN (?, ?) ORDER BY teamId, name');
            $playerStmt->execute([$mr['homeTeamId'], $mr['awayTeamId']]);
            echo json_encode(['ok'=>true,'msg'=>"Status → $s",'players'=>$playerStmt->fetchAll(), 'homeTeamId'=>$mr['homeTeamId'], 'awayTeamId'=>$mr['awayTeamId']]);
            exit;
            }
            echo json_encode(['ok'=>true,'msg'=>"Status → $s"]);
        }
        elseif ($op === 'set_player_of_match') {
          $playerId = trim($_POST['playerId'] ?? '');
          $playerStmt = $pdo->prepare('SELECT name FROM players WHERE id=? AND teamId IN (?, ?) LIMIT 1');
          $playerStmt->execute([$playerId, $mr['homeTeamId'], $mr['awayTeamId']]);
          $playerName = $playerStmt->fetchColumn();
          if (!$playerName) {
            echo json_encode(['ok'=>false,'msg'=>'That player is not registered to either team.']);
            exit;
          }
          $pdo->prepare("UPDATE matches SET playerOfMatchId=?, playerOfMatchName=? WHERE id=?")
            ->execute([$playerId, $playerName, $id]);
          echo json_encode(['ok'=>true,'msg'=>'Player of the Match saved.']);
        }
        elseif ($op === 'set_phase') {
            $p = $_POST['phase'] ?? 'First Half';
            $pdo->prepare("UPDATE matches SET phase=? WHERE id=?")->execute([$p,$id]);
            echo json_encode(['ok'=>true,'msg'=>"Phase → $p"]);
        }
        elseif ($op === 'set_minute') {
            $min = max(0, min(120, (int)($_POST['minute'] ?? 0)));
          // Move the server clock baseline with the manual adjustment so
          // the next sync resumes from the minute the admin entered.
          $pdo->prepare("UPDATE matches SET minute=?, liveStartedAt=CASE WHEN status='live' THEN DATE_SUB(NOW(), INTERVAL {$min} MINUTE) ELSE liveStartedAt END WHERE id=?")
            ->execute([$min, $id]);
            echo json_encode(['ok'=>true,'minute'=>$min]);
        }
        elseif ($op === 'tick') {
          $pdo->prepare("UPDATE matches SET minute = LEAST(minute+1,120) WHERE id=? AND status='live' AND minute < 120")->execute([$id]);
            $row = $pdo->prepare("SELECT minute FROM matches WHERE id=?");
            $row->execute([$id]);
          $state = $row->fetch(PDO::FETCH_ASSOC);
          if (!$state) {
            echo json_encode(['ok'=>false,'msg'=>'Match not found.']);
          } else {
            echo json_encode([
              'ok'=>true,
              'minute'=>(int)$state['minute'],
              'status'=>$state['status'],
              'active'=>$state['status'] === 'live' && (int)$state['minute'] < 120,
            ]);
          }
        }
        elseif ($op === 'add_event') {
            $side = $_POST['side']; // 'home' or 'away'
            $type = $_POST['type']; // Goal, Own Goal, Shootout Goal/Miss, cards, substitution
            $playerName = $_POST['playerName'] ?? '';
            $assistName = !empty($_POST['assistName']) ? $_POST['assistName'] : null;
            $isPenalty = !empty($_POST['isPenalty']) ? 1 : 0;
            
            // fetch match to get team names and current minute
            $m = $pdo->prepare("SELECT * FROM matches WHERE id=?");
            $m->execute([$id]); $m = $m->fetch();
            $beneficiaryTeamName = $side === 'home' ? $m['homeTeamName'] : $m['awayTeamName'];
            // An own-goal scorer belongs to the team that conceded, while the
            // score belongs to the opponent selected by the administrator.
            $teamName = $type === 'Own Goal'
                ? ($side === 'home' ? $m['awayTeamName'] : $m['homeTeamName'])
                : $beneficiaryTeamName;
            
            if ($type === 'Goal' || $type === 'Own Goal') {
                if ($side === 'home') {
                    $pdo->prepare("UPDATE matches SET homeScore = homeScore+1 WHERE id=?")->execute([$id]);
                } else {
                    $pdo->prepare("UPDATE matches SET awayScore = awayScore+1 WHERE id=?")->execute([$id]);
                }
            }
            
            $eid = 'me'.uniqid();
            $pdo->prepare("INSERT INTO match_events (id, matchId, minute, type, teamName, playerName, assistName, isPenalty) VALUES (?,?,?,?,?,?,?,?)")
                ->execute([$eid, $id, $m['minute'], $type, $teamName, $playerName, $assistName, $isPenalty]);
                
            $row = $pdo->prepare("SELECT homeScore,awayScore FROM matches WHERE id=?");
            $row->execute([$id]); $r = $row->fetch();
            $shootout = shootoutScorePhp($pdo, $id, $m['homeTeamName'], $m['awayTeamName']);
            echo json_encode(['ok'=>true,'home'=>(int)$r['homeScore'],'away'=>(int)$r['awayScore'],'shootoutHome'=>$shootout['home'],'shootoutAway'=>$shootout['away'],'eventId'=>$eid,'minute'=>(int)$m['minute']]);
        }
        elseif ($op === 'undo_last_event') {
            $side = $_POST['side']; // 'home' or 'away'
            $type = $_POST['type']; // Goal or Own Goal
            $m = $pdo->prepare("SELECT * FROM matches WHERE id=?");
            $m->execute([$id]); $m = $m->fetch();
            $teamName = $type === 'Own Goal'
                ? ($side === 'home' ? $m['awayTeamName'] : $m['homeTeamName'])
                : ($side === 'home' ? $m['homeTeamName'] : $m['awayTeamName']);
            
            // Find last event of this type for this team
            $lastEv = $pdo->prepare("SELECT id FROM match_events WHERE matchId=? AND type=? AND teamName=? ORDER BY minute DESC, id DESC LIMIT 1");
            $lastEv->execute([$id, $type, $teamName]);
            $lastEv = $lastEv->fetch();
            if ($lastEv) {
                $pdo->prepare("DELETE FROM match_events WHERE id=?")->execute([$lastEv['id']]);
                if ($type === 'Goal' || $type === 'Own Goal') {
                    if ($side === 'home') $pdo->prepare("UPDATE matches SET homeScore = GREATEST(homeScore-1,0) WHERE id=?")->execute([$id]);
                    else $pdo->prepare("UPDATE matches SET awayScore = GREATEST(awayScore-1,0) WHERE id=?")->execute([$id]);
                }
            }
            $row = $pdo->prepare("SELECT homeScore,awayScore FROM matches WHERE id=?");
            $row->execute([$id]); $r = $row->fetch();
            echo json_encode(['ok'=>true,'home'=>$r['homeScore'],'away'=>$r['awayScore']]);
        }
        elseif ($op === 'delete_event') {
            $eventId = $_POST['eventId'] ?? '';
            $evStmt = $pdo->prepare("SELECT * FROM match_events WHERE id=?");
            $evStmt->execute([$eventId]);
            $ev = $evStmt->fetch();
            if ($ev) {
                $mStmt = $pdo->prepare("SELECT * FROM matches WHERE id=?");
                $mStmt->execute([$ev['matchId']]);
                $m = $mStmt->fetch();
                if ($ev['type'] === 'Goal') {
                    if ($ev['teamName'] === $m['homeTeamName']) {
                        $pdo->prepare("UPDATE matches SET homeScore = GREATEST(homeScore-1,0) WHERE id=?")->execute([$m['id']]);
                    } else {
                        $pdo->prepare("UPDATE matches SET awayScore = GREATEST(awayScore-1,0) WHERE id=?")->execute([$m['id']]);
                    }
                } elseif ($ev['type'] === 'Own Goal') {
                    if ($ev['teamName'] === $m['homeTeamName']) {
                        $pdo->prepare("UPDATE matches SET awayScore = GREATEST(awayScore-1,0) WHERE id=?")->execute([$m['id']]);
                    } else {
                        $pdo->prepare("UPDATE matches SET homeScore = GREATEST(homeScore-1,0) WHERE id=?")->execute([$m['id']]);
                    }
                }
                $pdo->prepare("DELETE FROM match_events WHERE id=?")->execute([$eventId]);
                $row = $pdo->prepare("SELECT homeScore,awayScore FROM matches WHERE id=?");
                $row->execute([$ev['matchId']]); $r = $row->fetch();
                $shootout = shootoutScorePhp($pdo, $ev['matchId'], $m['homeTeamName'], $m['awayTeamName']);
                echo json_encode(['ok'=>true, 'home'=>(int)$r['homeScore'], 'away'=>(int)$r['awayScore'], 'shootoutHome'=>$shootout['home'], 'shootoutAway'=>$shootout['away']]);
            } else {
                echo json_encode(['ok'=>false, 'msg'=>'Event not found']);
            }
        }
        elseif ($op === 'update_event') {
            $eventId = $_POST['eventId'] ?? '';
            $minute = max(0, min(120, (int)($_POST['minute'] ?? 0)));
            $playerName = $_POST['playerName'] ?? '';
            $assistName = !empty($_POST['assistName']) ? $_POST['assistName'] : null;
            $isPenalty = !empty($_POST['isPenalty']) ? 1 : 0;

            $pdo->prepare("UPDATE match_events SET minute=?, playerName=?, assistName=?, isPenalty=? WHERE id=?")
                ->execute([$minute, $playerName, $assistName, $isPenalty, $eventId]);
            echo json_encode(['ok'=>true, 'minute'=>$minute, 'playerName'=>$playerName, 'assistName'=>$assistName, 'isPenalty'=>$isPenalty]);
        }
        elseif ($op === 'get_state') {
            $row = $pdo->prepare("SELECT homeScore,awayScore,minute,status,phase FROM matches WHERE id=?");
            $row->execute([$id]); $r = $row->fetch();
            echo json_encode(['ok'=>true,'data'=>$r]);
        }
        else {
            echo json_encode(['ok'=>false,'msg'=>'Unknown op']);
        }
    } catch (Exception $e) {
        echo json_encode(['ok'=>false,'msg'=>$e->getMessage()]);
    }
    exit;
}

// Ensure the remaining live-page columns exist before loading matches.
try {
  $cTeams = $pdo->query("SHOW COLUMNS FROM teams LIKE 'isExternal'")->fetch();
  if (!$cTeams) $pdo->exec("ALTER TABLE teams ADD COLUMN isExternal TINYINT(1) NOT NULL DEFAULT 0");
  $cMatches = $pdo->query("SHOW COLUMNS FROM matches LIKE 'isPrivate'")->fetch();
  if (!$cMatches) $pdo->exec("ALTER TABLE matches ADD COLUMN isPrivate TINYINT(1) NOT NULL DEFAULT 0");
  $pdo->exec("UPDATE matches SET minute=LEAST(120,GREATEST(0,TIMESTAMPDIFF(MINUTE,liveStartedAt,NOW()))) WHERE status='live' AND liveStartedAt IS NOT NULL");
} catch (Exception $e) {}

// Load all external teams or teams with isExternal=1
$externalTeamsMap = [];
try {
    $extQuery = $pdo->query("SELECT name FROM teams WHERE isExternal=1")->fetchAll(PDO::FETCH_COLUMN);
    foreach ($extQuery as $en) {
        $externalTeamsMap[$en] = true;
    }
} catch (Exception $e) {}

// ─── Load matches ──────────────────────────────────────────────────────────
$officialLeagueId = getOfficialLeagueId();
if (isOfficial() && $officialLeagueId) {
    $stmt = $pdo->prepare("SELECT * FROM matches WHERE status='live' AND leagueId=? ORDER BY kickoff DESC");
    $stmt->execute([$officialLeagueId]);
    $liveMatches = $stmt->fetchAll();
} else {
    $liveMatches = $pdo->query(
        "SELECT * FROM matches WHERE status='live' ORDER BY kickoff DESC"
    )->fetchAll();
}

// Pre-load full rosters and starters (from team_lineups) for the live matches
$teamAllPlayers = [];
$teamStarters = [];
$teamHasStartingXi = [];
$liveMatchTeams = [];
$teamIsExternal = [];
foreach ($liveMatches as $m) {
  $liveMatchTeams[$m['id']] = ['home' => $m['homeTeamName'], 'away' => $m['awayTeamName']];
  // Home team
  if (!isset($teamAllPlayers[$m['homeTeamName']])) {
    $players = $pdo->prepare("SELECT name FROM players WHERE teamName=? ORDER BY name");
    $players->execute([$m['homeTeamName']]);
    $teamAllPlayers[$m['homeTeamName']] = $players->fetchAll(PDO::FETCH_COLUMN);
  }
  $isHomeExt = !empty($externalTeamsMap[$m['homeTeamName']]) || count($teamAllPlayers[$m['homeTeamName']] ?? []) === 0;
  $teamIsExternal[$m['homeTeamName']] = $isHomeExt;

  if (!isset($teamStarters[$m['homeTeamName']])) {
    // Try fixture-specific lineup first, fall back to default lineup
    $stmt = $pdo->prepare("SELECT playerIds FROM team_lineups WHERE teamId=? AND matchId=? LIMIT 1");
    $stmt->execute([$m['homeTeamId'], $m['id']]);
    $row = $stmt->fetchColumn();
    if (!$row) {
      $stmt2 = $pdo->prepare("SELECT playerIds FROM team_lineups WHERE teamId=? AND matchId IS NULL LIMIT 1");
      $stmt2->execute([$m['homeTeamId']]);
      $row = $stmt2->fetchColumn();
    }
    if ($row) {
      $ids = json_decode($row, true);
      $names = [];
      foreach ($ids as $pid) {
        $pstmt = $pdo->prepare("SELECT name FROM players WHERE id=? LIMIT 1");
        $pstmt->execute([$pid]);
        $names[] = $pstmt->fetchColumn();
      }
      $teamStarters[$m['homeTeamName']] = array_values(array_filter($names));
    }
    if (empty($teamStarters[$m['homeTeamName']]) && !empty($teamAllPlayers[$m['homeTeamName']])) {
      $teamStarters[$m['homeTeamName']] = array_slice($teamAllPlayers[$m['homeTeamName']], 0, 11);
    }
    $teamHasStartingXi[$m['homeTeamName']] = $isHomeExt || (count($teamStarters[$m['homeTeamName']] ?? []) === 11);
  }

  // Away team
  if (!isset($teamAllPlayers[$m['awayTeamName']])) {
    $players = $pdo->prepare("SELECT name FROM players WHERE teamName=? ORDER BY name");
    $players->execute([$m['awayTeamName']]);
    $teamAllPlayers[$m['awayTeamName']] = $players->fetchAll(PDO::FETCH_COLUMN);
  }
  $isAwayExt = !empty($externalTeamsMap[$m['awayTeamName']]) || count($teamAllPlayers[$m['awayTeamName']] ?? []) === 0;
  $teamIsExternal[$m['awayTeamName']] = $isAwayExt;

  if (!isset($teamStarters[$m['awayTeamName']])) {
    $stmt = $pdo->prepare("SELECT playerIds FROM team_lineups WHERE teamId=? AND matchId=? LIMIT 1");
    $stmt->execute([$m['awayTeamId'], $m['id']]);
    $row = $stmt->fetchColumn();
    if (!$row) {
      $stmt2 = $pdo->prepare("SELECT playerIds FROM team_lineups WHERE teamId=? AND matchId IS NULL LIMIT 1");
      $stmt2->execute([$m['awayTeamId']]);
      $row = $stmt2->fetchColumn();
    }
    if ($row) {
      $ids = json_decode($row, true);
      $names = [];
      foreach ($ids as $pid) {
        $pstmt = $pdo->prepare("SELECT name FROM players WHERE id=? LIMIT 1");
        $pstmt->execute([$pid]);
        $names[] = $pstmt->fetchColumn();
      }
      $teamStarters[$m['awayTeamName']] = array_values(array_filter($names));
    }
    if (empty($teamStarters[$m['awayTeamName']]) && !empty($teamAllPlayers[$m['awayTeamName']])) {
      $teamStarters[$m['awayTeamName']] = array_slice($teamAllPlayers[$m['awayTeamName']], 0, 11);
    }
    $teamHasStartingXi[$m['awayTeamName']] = $isAwayExt || (count($teamStarters[$m['awayTeamName']] ?? []) === 11);
  }
  
  // Apply all past substitutions to get the current on-field players
  $subs = $pdo->prepare("SELECT teamName, playerName FROM match_events WHERE matchId=? AND type='Substitution' ORDER BY minute ASC, id ASC");
  $subs->execute([$m['id']]);
  foreach ($subs->fetchAll() as $subEv) {
    $rawSub = (string)($subEv['playerName'] ?? '');
    $parts = preg_split('/(\s*→\s*|\s*->\s*|\s*&rarr;\s*|\s+\?\s+|\s*\?\s*)/u', $rawSub);
    if (!$parts || count($parts) < 2) {
      if (strpos($rawSub, '→') !== false) {
        $parts = explode('→', $rawSub);
      } elseif (strpos($rawSub, '->') !== false) {
        $parts = explode('->', $rawSub);
      } elseif (strpos($rawSub, '?') !== false) {
        $parts = explode('?', $rawSub);
      }
    }
    if (is_array($parts) && count($parts) >= 2) {
      $out = trim(mb_strtolower($parts[0]));
      $in = trim($parts[1]);
      $tName = $subEv['teamName'];
      if (isset($teamStarters[$tName]) && is_array($teamStarters[$tName])) {
        $idx = false;
        foreach ($teamStarters[$tName] as $k => $st) {
          if (trim(mb_strtolower($st)) === $out) {
            $idx = $k;
            break;
          }
        }
        if ($idx !== false) {
          $teamStarters[$tName][$idx] = $in;
        }
      }
    }
  }
}

$teamAllPlayersJson = json_encode($teamAllPlayers);
$teamStartersJson = json_encode($teamStarters);
$teamHasStartingXiJson = json_encode($teamHasStartingXi);
$liveMatchTeamsJson = json_encode($liveMatchTeams);
$teamIsExternalJson = json_encode($teamIsExternal);

if (isOfficial() && $officialLeagueId) {
    $stmt = $pdo->prepare("SELECT * FROM matches WHERE status='upcoming' AND leagueId=? ORDER BY kickoff ASC LIMIT 10");
    $stmt->execute([$officialLeagueId]);
    $upcomingMatches = $stmt->fetchAll();

    $stmt = $pdo->prepare("SELECT * FROM matches WHERE status='fullTime' AND leagueId=? ORDER BY kickoff DESC LIMIT 5");
    $stmt->execute([$officialLeagueId]);
    $recentMatches = $stmt->fetchAll();
} else {
    $upcomingMatches = $pdo->query(
        "SELECT * FROM matches WHERE status='upcoming' ORDER BY kickoff ASC LIMIT 10"
    )->fetchAll();

    $recentMatches = $pdo->query(
        "SELECT * FROM matches WHERE status='fullTime' ORDER BY kickoff DESC LIMIT 5"
    )->fetchAll();
}

require __DIR__.'/header.php';
?>

<style>
.match-card{
  background:#0D2540;border:1px solid #1A3A5C;border-radius:14px;
  padding:20px 24px;margin:0 auto 16px auto;position:relative;overflow:hidden;
  max-width:900px;
}
.match-card.live-card{border-color:rgba(248,113,113,.5);background:rgba(248,113,113,.04);}
.live-badge{
  display:inline-flex;align-items:center;gap:6px;
  background:rgba(248,113,113,.15);color:#f87171;
  border:1px solid rgba(248,113,113,.4);border-radius:20px;
  padding:3px 12px;font-size:11px;font-weight:800;letter-spacing:.5px;
  animation:pulse 1.5s infinite;
}
.scoreboard{
  display:flex;align-items:center;justify-content:center;
  gap:16px;margin:16px 0;
}
.team-name{font-size:15px;font-weight:800;flex:1;text-align:center;color:#fff;}
.score-display{
  font-size:40px;font-weight:900;color:#D2B059;
  background:rgba(210,176,89,.1);border:1px solid rgba(210,176,89,.3);
  border-radius:12px;padding:8px 20px;min-width:120px;text-align:center;
  font-variant-numeric:tabular-nums;
}
.minute-badge{
  font-size:13px;font-weight:700;color:#f87171;
  background:rgba(248,113,113,.1);border:1px solid rgba(248,113,113,.3);
  border-radius:20px;padding:4px 14px;text-align:center;
  display:inline-block;
}
.ctrl-grid{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px;align-items:center;}
.btn-xl{padding:12px 22px;font-size:15px;font-weight:900;}
.btn-green{background:rgba(74,222,128,.15);color:#4ade80;border:1px solid rgba(74,222,128,.4);}
.btn-green:hover{background:rgba(74,222,128,.3);}
.btn-yellow{background:rgba(234,179,8,0.15);color:#eab308;border:1px solid rgba(234,179,8,0.4);}
.ticker-wrap{display:flex;align-items:center;gap:8px;}
.ticker-input{width:70px;text-align:center;font-size:18px;font-weight:800;padding:8px 10px;}
.auto-tick-wrap{display:flex;align-items:center;gap:10px;margin-top:10px;
  padding:10px 14px;background:rgba(255,255,255,.03);border-radius:10px;
  border:1px solid rgba(255,255,255,.07);}
.toggle{position:relative;display:inline-block;width:44px;height:24px;}
.toggle input{opacity:0;width:0;height:0;}
.slider{position:absolute;cursor:pointer;top:0;left:0;right:0;bottom:0;
  background:#1A3A5C;border-radius:24px;transition:.3s;}
.slider:before{position:absolute;content:"";height:18px;width:18px;left:3px;bottom:3px;
  background:#fff;border-radius:50%;transition:.3s;}
input:checked+.slider{background:#f87171;}
input:checked+.slider:before{transform:translateX(20px);}
.upcoming-item{
  display:flex;align-items:center;justify-content:space-between;
  padding:12px 16px;background:rgba(255,255,255,.03);border-radius:10px;
  border:1px solid #1A3A5C;margin-bottom:8px;
}
.match-vs{font-size:13px;font-weight:700;}
.match-meta{font-size:11px;color:#8BA3B8;margin-top:2px;}
.live-ctrl-grid{display:grid;grid-template-columns:1fr auto 1fr;gap:12px;align-items:start;}

@media (max-width:768px) {
  .scoreboard{flex-direction:column;gap:12px;}
  .score-display{font-size:32px;padding:6px 16px;}
  .team-name{font-size:18px;}
  .live-ctrl-grid{grid-template-columns:1fr;gap:24px;}
  .minute-center-col{order:-1;margin-bottom:8px;}
}

/* Modal Styles */
.modal-overlay{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.7);z-index:9999;align-items:center;justify-content:center;}
.modal-overlay.active{display:flex;}
.modal-content{background:#0D2540;border:1px solid #1A3A5C;border-radius:12px;padding:24px;width:100%;max-width:400px;}
.modal-title{font-size:18px;font-weight:800;color:#fff;margin-bottom:16px;}
.modal-form-group{margin-bottom:16px;}
.modal-form-group label{display:block;margin-bottom:6px;font-size:12px;color:#8BA3B8;}
.modal-form-group select, .modal-form-group input[type="text"], .modal-form-group input[type="number"] {width:100%;padding:10px;border-radius:8px;background:rgba(0,0,0,0.2);border:1px solid #1A3A5C;color:#fff;}
.btn-xs{padding:3px 7px;font-size:11px;border-radius:6px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;line-height:1;}
.btn-xs:hover{opacity:0.85;}
.event-row{transition:background .2s;}
.event-row:hover{background:rgba(255,255,255,.07) !important;}
</style>

<!-- Live matches section -->
<div style="margin-bottom:8px">
  <div style="display:flex;align-items:center;gap:10px;margin-bottom:16px">
    <span class="live-badge"><span class="material-icons-round" style="font-size:14px">fiber_manual_record</span>LIVE NOW</span>
    <span style="color:#8BA3B8;font-size:13px"><?= count($liveMatches) ?> match(es) in progress — App auto-refreshes every 30s</span>
  </div>

  <?php if (empty($liveMatches)): ?>
  <div style="text-align:center;padding:40px;color:#8BA3B8;border:1px dashed #1A3A5C;border-radius:14px">
    <span class="material-icons-round" style="font-size:48px;display:block;margin-bottom:12px">sports_soccer</span>
    No live matches right now. Start a match below.
  </div>
  <?php endif; ?>

  <?php foreach ($liveMatches as $m): ?>
  <?php
    $homeIsExt = !empty($teamIsExternal[$m['homeTeamName']]);
    $awayIsExt = !empty($teamIsExternal[$m['awayTeamName']]);
    $homeLineupReady = $homeIsExt || !empty($teamHasStartingXi[$m['homeTeamName']]);
    $awayLineupReady = $awayIsExt || !empty($teamHasStartingXi[$m['awayTeamName']]);
    $shootout = shootoutScorePhp($pdo, $m['id'], $m['homeTeamName'], $m['awayTeamName']);
  ?>
  <div class="match-card live-card" id="card-<?= e($m['id']) ?>">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px">
      <span class="live-badge"><span class="material-icons-round" style="font-size:14px">fiber_manual_record</span>LIVE</span>
      <div style="display:flex;align-items:center;gap:8px;">
        <select class="ticker-input" style="font-size:13px;width:auto;" onchange="setPhase('<?= e($m['id']) ?>', this.value)">
            <?php 
            $phases = ['First Half', '1st Half Stoppage', 'Half Time', 'Second Half', '2nd Half Stoppage', 'Full Time', 'Extra Time 1st', 'Extra Time 2nd', 'Penalties'];
            foreach($phases as $p) {
                $sel = ($m['phase'] ?? 'First Half') === $p ? 'selected' : '';
                echo "<option $sel value='$p'>$p</option>";
            }
            ?>
        </select>
        <span class="minute-badge" id="min-<?= e($m['id']) ?>"><?= e($m['minute']) ?>'</span>
      </div>
    </div>

    <!-- Scoreboard -->
    <div class="scoreboard">
      <div class="team-name">
        <?= e($m['homeTeamName']) ?>
        <?php if ($homeIsExt): ?>
          <span style="display:block;font-size:11px;font-weight:600;color:#f59e0b;margin-top:2px;">(External Opponent)</span>
        <?php endif; ?>
      </div>
      <div class="score-display" id="score-<?= e($m['id']) ?>">
        <?= e($m['homeScore']) ?> – <?= e($m['awayScore']) ?>
      </div>
      <div class="team-name">
        <?= e($m['awayTeamName']) ?>
        <?php if ($awayIsExt): ?>
          <span style="display:block;font-size:11px;font-weight:600;color:#f59e0b;margin-top:2px;">(External Opponent)</span>
        <?php endif; ?>
      </div>
    </div>
    <div id="shootout-<?= e($m['id']) ?>" style="text-align:center;font-size:12px;color:#D2B059;margin-top:-10px;margin-bottom:12px;<?= ($shootout['home'] || $shootout['away']) ? '' : 'display:none;' ?>">
      Penalties: <strong><span class="shootout-home"><?= $shootout['home'] ?></span> – <span class="shootout-away"><?= $shootout['away'] ?></span></strong>
    </div>

    <div style="text-align:center;font-size:12px;color:#8BA3B8;margin-bottom:14px">
      <?= e($m['competition']) ?> · <?= e($m['venue']) ?>
    </div>

    <!-- Controls -->
    <div class="live-ctrl-grid">
      <!-- Home controls -->
      <div style="display:flex;flex-direction:column;gap:6px;align-items:center">
        <?php if ($homeIsExt): ?>
          <div style="width:100%;padding:6px;text-align:center;background:rgba(245,158,11,.12);border:1px solid rgba(245,158,11,.3);border-radius:8px;color:#f59e0b;font-size:11px;font-weight:600">
            External Team (Names entered directly)
          </div>
        <?php elseif (!$homeLineupReady): ?>
          <div style="width:100%;padding:9px;text-align:center;border:1px dashed #D2B059;border-radius:8px;color:#D2B059;font-size:12px">Starting XI not selected</div>
        <?php endif; ?>
        <button class="btn btn-green btn-xl" style="width:100%" <?= !$homeLineupReady ? 'disabled title="Select a starting XI first"' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'home', 'Goal', '<?= js($m['homeTeamName']) ?>')">
          <span class="material-icons-round">sports_soccer</span> GOAL <?= mb_strtoupper(e($m['homeTeamName'])) ?>
        </button>
        <button class="btn btn-outline btn-sm" style="width:100%" <?= !$awayLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'home', 'Own Goal', '<?= js($m['homeTeamName']) ?>')">Own Goal by <?= e($m['awayTeamName']) ?></button>
        <div style="display:flex;gap:4px;width:100%">
          <button class="btn btn-outline btn-sm" style="flex:1" <?= !$homeLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'home', 'Shootout Goal', '<?= js($m['homeTeamName']) ?>')">Pen ✓</button>
          <button class="btn btn-outline btn-sm" style="flex:1" <?= !$homeLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'home', 'Shootout Miss', '<?= js($m['homeTeamName']) ?>')">Pen ✕</button>
        </div>
        <div style="display:flex;gap:4px;width:100%">
            <button class="btn btn-yellow btn-sm" style="flex:1" <?= !$homeLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'home', 'Yellow Card', '<?= js($m['homeTeamName']) ?>')">Y. Card</button>
            <button class="btn btn-danger btn-sm" style="flex:1" <?= !$homeLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'home', 'Red Card', '<?= js($m['homeTeamName']) ?>')">R. Card</button>
        </div>
        <button class="btn btn-outline btn-sm" onclick="undoGoal('<?= e($m['id']) ?>','home')">
          ↩ Undo Last Goal
        </button>
        <button class="btn btn-outline btn-sm" onclick="undoOwnGoal('<?= e($m['id']) ?>','home')">↩ Undo Own Goal</button>
        <button class="btn btn-outline btn-sm" <?= !$homeLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'home', 'Substitution', '<?= js($m['homeTeamName']) ?>')">Substitute</button>
      </div>

      <!-- Minute control -->
      <div class="minute-center-col" style="text-align:center;display:flex;flex-direction:column;align-items:center;">
        <div style="font-size:11px;color:#8BA3B8;margin-bottom:6px;text-transform:uppercase;letter-spacing:.5px">Minute</div>
        <div class="ticker-wrap">
          <button class="btn btn-outline btn-sm" onclick="adjustMin('<?= e($m['id']) ?>',-1)">−</button>
          <input class="ticker-input" type="number" id="min-input-<?= e($m['id']) ?>"
            value="<?= e($m['minute']) ?>" min="0" max="120"
            onchange="setMinute('<?= e($m['id']) ?>',this.value)"/>
          <button class="btn btn-outline btn-sm" onclick="adjustMin('<?= e($m['id']) ?>',1)">+</button>
        </div>
        <div class="auto-tick-wrap" style="margin-top:8px">
          <label class="toggle">
            <input type="checkbox" id="autotick-<?= e($m['id']) ?>"
              onchange="toggleAutoTick('<?= e($m['id']) ?>',this.checked)"/>
            <span class="slider"></span>
          </label>
          <span style="font-size:12px;color:#8BA3B8">Auto-tick minute</span>
        </div>
      </div>

      <!-- Away controls -->
      <div style="display:flex;flex-direction:column;gap:6px;align-items:center">
        <?php if ($awayIsExt): ?>
          <div style="width:100%;padding:6px;text-align:center;background:rgba(245,158,11,.12);border:1px solid rgba(245,158,11,.3);border-radius:8px;color:#f59e0b;font-size:11px;font-weight:600">
            External Team (Names entered directly)
          </div>
        <?php elseif (!$awayLineupReady): ?>
          <div style="width:100%;padding:9px;text-align:center;border:1px dashed #D2B059;border-radius:8px;color:#D2B059;font-size:12px">Starting XI not selected</div>
        <?php endif; ?>
        <button class="btn btn-green btn-xl" style="width:100%" <?= !$awayLineupReady ? 'disabled title="Select a starting XI first"' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'away', 'Goal', '<?= js($m['awayTeamName']) ?>')">
           GOAL <?= mb_strtoupper(e($m['awayTeamName'])) ?> <span class="material-icons-round">sports_soccer</span>
        </button>
        <button class="btn btn-outline btn-sm" style="width:100%" <?= !$homeLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'away', 'Own Goal', '<?= js($m['awayTeamName']) ?>')">Own Goal by <?= e($m['homeTeamName']) ?></button>
        <div style="display:flex;gap:4px;width:100%">
          <button class="btn btn-outline btn-sm" style="flex:1" <?= !$awayLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'away', 'Shootout Goal', '<?= js($m['awayTeamName']) ?>')">Pen ✓</button>
          <button class="btn btn-outline btn-sm" style="flex:1" <?= !$awayLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'away', 'Shootout Miss', '<?= js($m['awayTeamName']) ?>')">Pen ✕</button>
        </div>
        <div style="display:flex;gap:4px;width:100%">
            <button class="btn btn-yellow btn-sm" style="flex:1" <?= !$awayLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'away', 'Yellow Card', '<?= js($m['awayTeamName']) ?>')">Y. Card</button>
            <button class="btn btn-danger btn-sm" style="flex:1" <?= !$awayLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'away', 'Red Card', '<?= js($m['awayTeamName']) ?>')">R. Card</button>
        </div>
        <button class="btn btn-outline btn-sm" onclick="undoGoal('<?= e($m['id']) ?>','away')">
          ↩ Undo Last Goal
        </button>
        <button class="btn btn-outline btn-sm" onclick="undoOwnGoal('<?= e($m['id']) ?>','away')">↩ Undo Own Goal</button>
        <button class="btn btn-outline btn-sm" <?= !$awayLineupReady ? 'disabled' : '' ?> onclick="openEventModal('<?= js($m['id']) ?>', 'away', 'Substitution', '<?= js($m['awayTeamName']) ?>')">Substitute</button>
      </div>
    </div>

    <!-- Match Event Log -->
    <?php
      $evStmt = $pdo->prepare("SELECT * FROM match_events WHERE matchId=? ORDER BY minute ASC, id ASC");
      $evStmt->execute([$m['id']]);
      $matchEvents = $evStmt->fetchAll();
    ?>
    <div style="margin-top:20px;padding-top:16px;border-top:1px solid rgba(255,255,255,.07);">
      <div style="font-size:12px;font-weight:700;color:#8BA3B8;text-transform:uppercase;letter-spacing:.6px;margin-bottom:10px;">
        Match Events (<?= count($matchEvents) ?>)
      </div>
      <div id="events-log-<?= e($m['id']) ?>" style="display:flex;flex-direction:column;gap:6px;max-height:260px;overflow-y:auto;">
        <?php if (empty($matchEvents)): ?>
          <div style="color:#8BA3B8;font-size:12px;font-style:italic;text-align:center;padding:12px 0;">No events recorded yet.</div>
        <?php endif; ?>
        <?php foreach ($matchEvents as $ev): ?>
          <?php
            $iconMap = [
              'Goal'        => '⚽',
              'Own Goal'    => '⚽',
              'Shootout Goal' => '✓',
              'Shootout Miss' => '✕',
              'Yellow Card' => '🟨',
              'Red Card'    => '🟥',
              'Substitution'=> '🔄',
            ];
            $icon = $iconMap[$ev['type']] ?? '•';

            $colorMap = [
              'Goal'        => '#22c55e',
              'Own Goal'    => '#ef4444',
              'Shootout Goal' => '#22c55e',
              'Shootout Miss' => '#ef4444',
              'Yellow Card' => '#eab308',
              'Red Card'    => '#ef4444',
              'Substitution'=> '#60a5fa',
            ];
            $color = $colorMap[$ev['type']] ?? '#8BA3B8';

            // Parse substitution: playerName is "Out -> In", assistName is the "Out" fallback
            $subOut = '';
            $subIn  = '';
            if ($ev['type'] === 'Substitution') {
              $raw = $ev['playerName'] ?? '';
              if (strpos($raw, '->') !== false) {
                [$subOut, $subIn] = array_map('trim', explode('->', $raw, 2));
              } elseif (strpos($raw, '→') !== false) {
                [$subOut, $subIn] = array_map('trim', explode('→', $raw, 2));
              } elseif (!empty($ev['assistName'])) {
                $subOut = trim($ev['assistName']);
                $subIn  = trim($raw);
              } else {
                $subIn = trim($raw);
              }
            }
          ?>
          <div id="event-row-<?= e($ev['id']) ?>" class="event-row" style="display:flex;align-items:center;gap:8px;background:rgba(255,255,255,.04);border-radius:8px;padding:8px 10px;">
            <span style="font-size:16px;line-height:1"><?= $icon ?></span>
            <div style="flex:1;min-width:0;">
              <?php if ($ev['type'] === 'Substitution'): ?>
                <?php if ($subIn !== ''): ?>
                  <div style="font-size:13px;font-weight:700;color:#22c55e;">↑ IN: <span class="event-subin-text"><?= e($subIn) ?></span></div>
                <?php endif; ?>
                <?php if ($subOut !== ''): ?>
                  <div style="font-size:12px;font-weight:600;color:#ef4444;">↓ OUT: <span class="event-subout-text"><?= e($subOut) ?></span></div>
                <?php endif; ?>
                <div style="font-size:11px;color:#8BA3B8;margin-top:2px;"><?= e($ev['teamName']) ?></div>
              <?php else: ?>
                <div class="event-player-text" style="font-size:13.5px;font-weight:700;color:<?= $color ?>;"><?= e($ev['playerName']) ?></div>
                <?php if (!empty($ev['assistName'])): ?>
                  <div class="event-assist-text" style="font-size:11px;color:#8BA3B8;">Assist: <?= e($ev['assistName']) ?></div>
                <?php else: ?>
                  <div class="event-assist-text" style="font-size:11px;color:#8BA3B8;display:none;"></div>
                <?php endif; ?>
                <?php if ($ev['type'] === 'Shootout Goal' || $ev['type'] === 'Shootout Miss'): ?>
                  <div class="event-penalty-text" style="font-size:11px;color:#D2B059;">Penalty shootout · <?= $ev['type'] === 'Shootout Goal' ? 'Scored' : 'Missed' ?></div>
                <?php elseif (!empty($ev['isPenalty'])): ?>
                  <div class="event-penalty-text" style="font-size:11px;color:#D2B059;">(Penalty)</div>
                <?php endif; ?>
                <div style="font-size:11px;color:#8BA3B8;"><?= e($ev['teamName']) ?></div>
              <?php endif; ?>
            </div>
            <div style="display:flex;align-items:center;gap:6px;">
              <span class="event-min-text" style="font-size:12px;font-weight:800;color:<?= $color ?>;white-space:nowrap;margin-right:2px;"><?= e($ev['minute']) ?>'</span>
              <button type="button" class="btn btn-outline btn-xs" title="Edit event" onclick="openEditEventModal('<?= e($ev['id']) ?>', '<?= e($m['id']) ?>', '<?= e($ev['type']) ?>', <?= (int)$ev['minute'] ?>, '<?= e(addslashes($ev['playerName'])) ?>', '<?= e(addslashes($ev['assistName'] ?? '')) ?>', <?= !empty($ev['isPenalty']) ? 1 : 0 ?>, '<?= e(addslashes($ev['teamName'])) ?>')" style="padding:3px 6px;">
                <span class="material-icons-round" style="font-size:14px">edit</span>
              </button>
              <button type="button" class="btn btn-outline btn-xs" title="Delete event" onclick="deleteEvent('<?= e($ev['id']) ?>', '<?= e($m['id']) ?>', '<?= e($ev['type']) ?>')" style="padding:3px 6px;color:#ef4444;border-color:rgba(239,68,68,0.3);">
                <span class="material-icons-round" style="font-size:14px">delete</span>
              </button>
            </div>
          </div>
        <?php endforeach; ?>
      </div>
    </div>

    <!-- Status controls -->
    <div style="margin-top:24px;padding-top:16px;border-top:1px solid rgba(255,255,255,.07);display:flex;gap:8px;flex-wrap:wrap;justify-content:center;">
      <button class="btn btn-outline btn-sm" onclick="setStatus('<?= e($m['id']) ?>','fullTime')">
        <span class="material-icons-round">sports_score</span> Full Time
      </button>
      <button class="btn btn-outline btn-sm" onclick="setStatus('<?= e($m['id']) ?>','postponed')">
        <span class="material-icons-round">pause</span> Postpone
      </button>
      <span style="flex:1"></span>
      <span style="font-size:11px;color:#8BA3B8;align-self:center">
        <span id="lastpush-<?= e($m['id']) ?>">—</span>
      </span>
    </div>
  </div>
  <?php endforeach; ?>
</div>

<!-- Upcoming: start as live -->
<div style="margin-bottom:24px">
  <div class="section-header">
    <span class="section-title">Upcoming Matches — Start as Live</span>
    <a href="matches.php?action=add" class="btn btn-outline btn-sm"><span class="material-icons-round">add</span>Schedule Match</a>
  </div>
  <?php foreach ($upcomingMatches as $m): ?>
  <div class="upcoming-item">
    <div>
      <div class="match-vs"><?= e($m['homeTeamName']) ?> vs <?= e($m['awayTeamName']) ?></div>
      <div class="match-meta"><?= e($m['competition']) ?> · <?= date('d M Y H:i', strtotime($m['kickoff'])) ?></div>
    </div>
    <button class="btn btn-gold btn-sm" onclick="startLive('<?= e($m['id']) ?>')">
      <span class="material-icons-round">play_arrow</span> Start LIVE
    </button>
  </div>
  <?php endforeach; ?>
  <?php if (empty($upcomingMatches)): ?>
  <div style="color:#8BA3B8;font-size:13px;padding:12px">No upcoming matches. <a href="matches.php?action=add" style="color:#D2B059">Schedule one →</a></div>
  <?php endif; ?>
</div>

<!-- Recent full time -->
<?php if (!empty($recentMatches)): ?>
<div>
  <div class="section-title" style="margin-bottom:12px">Recent Finished Matches</div>
  <?php foreach($recentMatches as $m): ?>
  <div class="upcoming-item" style="opacity:.7">
    <div>
      <div class="match-vs"><?= e($m['homeTeamName']) ?> <?= e($m['homeScore']) ?>–<?= e($m['awayScore']) ?> <?= e($m['awayTeamName']) ?></div>
      <div class="match-meta"><?= date('d M Y', strtotime($m['kickoff'])) ?></div>
    </div>
    <button class="btn btn-outline btn-sm" onclick="startLive('<?= e($m['id']) ?>')">
      <span class="material-icons-round">replay</span> Restart
    </button>
  </div>
  <?php endforeach; ?>
</div>
<?php endif; ?>

<!-- Event Modal -->
<div class="modal-overlay" id="eventModal">
  <div class="modal-content">
    <div class="modal-title" id="eventModalTitle">Add Event</div>
    <form id="eventForm" onsubmit="submitEvent(event)">
      <input type="hidden" id="eventMatchId" />
      <input type="hidden" id="eventSide" />
      <input type="hidden" id="eventType" />
      
      <!-- Player / Scorer Selector or Text Input -->
      <div class="modal-form-group" id="scorerGroup">
        <label id="scorerLabel">Player (Scorer / Carded)</label>
        <select id="eventPlayerName"></select>
        <input type="text" id="eventPlayerNameText" placeholder="Type player name..." style="display:none;" />
      </div>

      <!-- Assist Selector or Text Input -->
      <div class="modal-form-group" id="assistGroup">
        <label id="assistLabel">Assist (Optional)</label>
        <select id="eventAssistName"></select>
        <input type="text" id="eventAssistNameText" placeholder="Type assist player name (optional)..." style="display:none;" />
      </div>

      <!-- Substitution Selectors or Text Inputs -->
      <div class="modal-form-group" id="subGroup" style="display:none">
        <label id="subOutLabel">Player Out</label>
        <select id="eventOutName"></select>
        <input type="text" id="eventOutNameText" placeholder="Type outgoing player name..." style="display:none;" />
      </div>
      <div class="modal-form-group" id="subInGroup" style="display:none">
        <label id="subInLabel">Player In</label>
        <select id="eventInName"></select>
        <input type="text" id="eventInNameText" placeholder="Type incoming player name..." style="display:none;" />
      </div>
      
      <div class="modal-form-group" id="penaltyGroup" style="display:flex;align-items:center;gap:10px;">
        <label style="margin:0"><input type="checkbox" id="eventIsPenalty" /> Penalty Goal?</label>
      </div>
      
      <div style="display:flex;gap:10px;margin-top:24px;">
        <button type="submit" id="saveEventSubmitBtn" class="btn btn-gold" style="flex:1">Save Event</button>
        <button type="button" class="btn btn-outline" style="flex:1" onclick="closeEventModal()">Cancel</button>
      </div>
    </form>
  </div>
</div>

<!-- Edit Event Modal -->
<div class="modal-overlay" id="editEventModal">
  <div class="modal-content">
    <div class="modal-title" id="editEventModalTitle">Edit Match Event</div>
    <form id="editEventForm" onsubmit="submitEditEvent(event)">
      <input type="hidden" id="editEventId" />
      <input type="hidden" id="editEventMatchId" />
      <input type="hidden" id="editEventType" />
      <input type="hidden" id="editEventTeamName" />

      <div class="modal-form-group">
        <label>Minute (0 - 120)</label>
        <input type="number" id="editEventMinute" min="0" max="120" required />
      </div>

      <!-- Player Selector / Text Input -->
      <div class="modal-form-group" id="editPlayerGroup">
        <label id="editPlayerLabel">Player</label>
        <select id="editEventPlayerSelect"></select>
        <input type="text" id="editEventPlayerText" placeholder="Type player name..." style="display:none;" />
      </div>

      <!-- Assist Selector / Text Input -->
      <div class="modal-form-group" id="editAssistGroup">
        <label>Assist (Optional)</label>
        <select id="editEventAssistSelect"></select>
        <input type="text" id="editEventAssistText" placeholder="Type assist player name (optional)..." style="display:none;" />
      </div>

      <!-- Substitution Selectors / Text Inputs -->
      <div class="modal-form-group" id="editSubGroup" style="display:none">
        <label id="editSubOutLabel">Player Out</label>
        <select id="editEventOutSelect"></select>
        <input type="text" id="editEventOutText" placeholder="Type outgoing player name..." style="display:none;" />
      </div>
      <div class="modal-form-group" id="editSubInGroup" style="display:none">
        <label id="editSubInLabel">Player In</label>
        <select id="editEventInSelect"></select>
        <input type="text" id="editEventInText" placeholder="Type incoming player name..." style="display:none;" />
      </div>

      <div class="modal-form-group" id="editPenaltyGroup" style="display:flex;align-items:center;gap:10px;">
        <label style="margin:0"><input type="checkbox" id="editEventIsPenalty" /> Penalty Goal?</label>
      </div>

      <div style="display:flex;gap:10px;margin-top:24px;">
        <button type="submit" id="saveEditEventBtn" class="btn btn-gold" style="flex:1">Save Changes</button>
        <button type="button" class="btn btn-outline" style="flex:1" onclick="closeEditEventModal()">Cancel</button>
      </div>
    </form>
  </div>
</div>

<script>
const API = 'live.php';
const autoTickers = {}; // matchId → intervalId
const autoTickRequests = {}; // matchId → request in flight
const teamAllPlayers = <?= $teamAllPlayersJson ?>;
const teamStarters = <?= $teamStartersJson ?>;
const teamHasStartingXi = <?= $teamHasStartingXiJson ?>;
const liveMatchTeams = <?= $liveMatchTeamsJson ?>;
const teamIsExternal = <?= $teamIsExternalJson ?>;

function post(op, id, extra = {}) {
  const fd = new FormData();
  fd.append('op', op); fd.append('id', id);
  for (const [k,v] of Object.entries(extra)) fd.append(k, v);
  return fetch(API, { method:'POST', body:fd }).then(async response => {
    const body = await response.text();
    let data;
    try { data = JSON.parse(body); } catch (_) {
      throw new Error(`Server returned HTTP ${response.status} instead of JSON.`);
    }
    if (!response.ok) throw new Error(data.msg || `Request failed with HTTP ${response.status}.`);
    return data;
  });
}

function updateScoreDisplay(id, home, away) {
  const el = document.getElementById('score-'+id);
  if (el) {
    el.textContent = home + ' – ' + away;
    el.style.transition = 'background .2s';
    el.style.background = 'rgba(210,176,89,.3)';
    setTimeout(() => el.style.background = 'rgba(210,176,89,.1)', 600);
  }
}

function updateShootoutDisplay(id, home, away) {
  const el = document.getElementById('shootout-' + id);
  if (!el || home === undefined || away === undefined) return;
  el.style.display = 'block';
  el.querySelector('.shootout-home').textContent = home;
  el.querySelector('.shootout-away').textContent = away;
}

function updateMinDisplay(id, min) {
  const el = document.getElementById('min-'+id);
  if (el) el.textContent = min + "'";
  const inp = document.getElementById('min-input-'+id);
  if (inp && document.activeElement !== inp) inp.value = min;
}

function pushTime(id) {
  if (localStorage.getItem('autotick_' + id) === '1') return;
  const el = document.getElementById('lastpush-'+id);
  if (el) el.textContent = 'Last push: ' + new Date().toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'});
}

function undoGoal(id, side) {
  if (!confirm('Undo the last goal?')) return;
  post('undo_last_event', id, {side: side, type: 'Goal'}).then(d => {
    if (d.ok) { updateScoreDisplay(id, d.home, d.away); pushTime(id); }
  });
}

function undoOwnGoal(id, side) {
  if (!confirm('Undo the last own goal?')) return;
  post('undo_last_event', id, {side: side, type: 'Own Goal'}).then(d => {
    if (d.ok) { updateScoreDisplay(id, d.home, d.away); pushTime(id); }
  });
}

function setMinute(id, val) {
  post('set_minute', id, {minute: val}).then(d => {
    if (d.ok) {
      updateMinDisplay(id, d.minute);
      pushTime(id);
      if (localStorage.getItem('autotick_' + id) === '1') {
        localStorage.setItem('autotick_last_' + id, Date.now().toString());
      }
    }
  });
}

function adjustMin(id, delta) {
  const inp = document.getElementById('min-input-'+id);
  const newVal = Math.max(0, Math.min(120, parseInt(inp.value||0) + delta));
  inp.value = newVal;
  updateMinDisplay(id, newVal);
  setMinute(id, newVal);
}

function setPhase(id, val) {
  post('set_phase', id, {phase: val}).then(d => {
    if (d.ok) { pushTime(id); }
  });
}

function toggleAutoTick(id, enabled) {
  if (autoTickers[id]) { clearInterval(autoTickers[id]); delete autoTickers[id]; }
  const flagKey = 'autotick_' + id;
  const lastKey = 'autotick_last_' + id;

  if (!enabled) {
    stopAutoTick(id, 'Auto-tick paused');
    return;
  }

  localStorage.setItem(flagKey, '1');
  if (!localStorage.getItem(lastKey)) localStorage.setItem(lastKey, Date.now().toString());
  const el = document.getElementById('lastpush-'+id);
  if (el) el.textContent = 'Auto-tick ON';

  autoTickers[id] = setInterval(() => {
    if (localStorage.getItem(flagKey) !== '1' || autoTickRequests[id]) return;
    const now = Date.now();
    const last = parseInt(localStorage.getItem(lastKey) || now.toString(), 10);
    if (now - last < 60000) return;

    autoTickRequests[id] = true;
    post('tick', id).then(d => {
      if (!d.ok) throw new Error(d.msg || 'Ticker update failed.');
      updateMinDisplay(id, d.minute);
      localStorage.setItem(lastKey, Date.now().toString());
      if (d.active === false) stopAutoTick(id, d.status === 'live' ? 'Minute limit reached' : 'Match is no longer live');
    }).catch(error => {
      stopAutoTick(id, 'Ticker stopped: ' + error.message);
    }).finally(() => {
      delete autoTickRequests[id];
    });
  }, 1000);
}

function stopAutoTick(id, message) {
  if (autoTickers[id]) { clearInterval(autoTickers[id]); delete autoTickers[id]; }
  localStorage.removeItem('autotick_' + id);
  localStorage.removeItem('autotick_last_' + id);
  const cb = document.getElementById('autotick-' + id);
  if (cb) cb.checked = false;
  const el = document.getElementById('lastpush-' + id);
  if (el) el.textContent = message || 'Auto-tick paused';
}


function setStatus(id, status) {
  const labels = {fullTime:'end the match?', postponed:'postpone this match?'};
  if (!confirm('Are you sure you want to '+(labels[status]||status))) return;
  if (status === 'fullTime' || status === 'postponed') {
    localStorage.removeItem('autotick_' + id);
    localStorage.removeItem('autotick_last_' + id);
  }
  post('set_status', id, {status}).then(d => {
    if (!d.ok) return alert(d.msg || 'Could not update match status.');
    if (status === 'fullTime') return openPlayerOfMatchPicker(id, d.players || [], d.homeTeamId, d.awayTeamId);
    location.reload();
  });
}

function openPlayerOfMatchPicker(matchId, players, homeTeamId, awayTeamId) {
  const old = document.getElementById('playerOfMatchModal');
  if (old) old.remove();

  const modal = document.createElement('div');
  modal.id = 'playerOfMatchModal';
  modal.style.cssText = 'position:fixed;inset:0;z-index:10000;background:rgba(0,0,0,.75);display:flex;align-items:center;justify-content:center;padding:16px;';
  const options = players.map(player =>
    `<option value="${escapeHtml(player.id)}">${escapeHtml(player.name)} (${player.teamId === homeTeamId ? 'Home' : player.teamId === awayTeamId ? 'Away' : 'Team'})</option>`
  ).join('');
  modal.innerHTML = `<div style="width:460px;max-width:100%;background:#0D2540;border:1px solid #D2B059;border-radius:14px;padding:24px;">
    <div style="font-size:18px;font-weight:800;color:#D2B059;margin-bottom:8px;">⭐ Player of the Match</div>
    <div style="font-size:13px;color:#8BA3B8;margin-bottom:16px;">The match is full time. Select the best player now, or choose them later from Edit Match.</div>
    ${players.length ? `<select id="playerOfMatchPicker" style="width:100%;margin-bottom:16px;"><option value="">Select a player...</option>${options}</select>` : '<div style="color:#fbbf24;margin-bottom:16px;">No registered players are available for this match.</div>'}
    <div style="display:flex;justify-content:flex-end;gap:8px;">
      <button type="button" class="btn btn-outline" onclick="document.getElementById('playerOfMatchModal').remove();location.reload();">Choose Later</button>
      ${players.length ? '<button type="button" class="btn btn-gold" onclick="savePlayerOfMatch(\'' + matchId + '\')">Save ⭐ Player</button>' : ''}
    </div>
  </div>`;
  document.body.appendChild(modal);
}

function savePlayerOfMatch(matchId) {
  const playerId = document.getElementById('playerOfMatchPicker')?.value;
  if (!playerId) return alert('Select a player first.');
  post('set_player_of_match', matchId, {playerId}).then(d => {
    if (!d.ok) return alert(d.msg || 'Could not save Player of the Match.');
    location.reload();
  });
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[character]));
}

function startLive(id) {
  if (!confirm('Start this match as LIVE?')) return;
  post('set_live', id).then(d => {
    if (d.ok) location.reload();
  });
}

// ─── Modal Logic ───
function openEventModal(matchId, side, type, teamName) {
    document.getElementById('eventMatchId').value = matchId;
    document.getElementById('eventSide').value = side;
    document.getElementById('eventType').value = type;
    const titleEl = document.getElementById('eventModalTitle');
    titleEl.textContent = type + ' - ' + teamName;
    titleEl.dataset.team = teamName;

    // For own goals, the player who scored the own goal is from the opposing team
    const matchTeams = liveMatchTeams[matchId] || {};
    const eventTeamName = type === 'Own Goal'
      ? (side === 'home' ? matchTeams.away : matchTeams.home)
      : teamName;

    // Is this team external (no roster)?
    const isExt = Boolean(teamIsExternal[eventTeamName] || (!teamAllPlayers[eventTeamName] || teamAllPlayers[eventTeamName].length === 0));

    // Select/text elements
    const pSelect = document.getElementById('eventPlayerName');
    const pText   = document.getElementById('eventPlayerNameText');
    const aSelect = document.getElementById('eventAssistName');
    const aText   = document.getElementById('eventAssistNameText');
    const outSelect = document.getElementById('eventOutName');
    const outText   = document.getElementById('eventOutNameText');
    const inSelect  = document.getElementById('eventInName');
    const inText    = document.getElementById('eventInNameText');

    if (isExt) {
      // Show text inputs, hide selects
      pSelect.style.display = 'none';  pText.style.display = 'block';  pText.value = '';
      aSelect.style.display = 'none';  aText.style.display = 'block';  aText.value = '';
      outSelect.style.display = 'none'; outText.style.display = 'block'; outText.value = '';
      inSelect.style.display = 'none';  inText.style.display = 'block';  inText.value = '';
    } else {
      // Hide text inputs, show selects (normal roster mode)
      pText.style.display = 'none';  pSelect.style.display = 'block';
      aText.style.display = 'none';  aSelect.style.display = 'block';
      outText.style.display = 'none'; outSelect.style.display = 'block';
      inText.style.display = 'none';  inSelect.style.display = 'block';

      // Guard: only alert if NOT external and truly no players at all
      const starters = teamStarters[eventTeamName] || [];
      const all = teamAllPlayers[eventTeamName] || [];
      if (!teamHasStartingXi[eventTeamName] && starters.length === 0 && all.length === 0) {
        alert('No players registered for ' + eventTeamName + '.');
        return;
      }

      pSelect.innerHTML = '<option value="">Select player...</option>';
      aSelect.innerHTML = '<option value="">None</option>';
      outSelect.innerHTML = '<option value="">Select outgoing player...</option>';
      inSelect.innerHTML = '<option value="">Select incoming player...</option>';

      const onPitchList = starters.length > 0 ? starters : all.slice(0, 11);
      const benchList = all.filter(p => !onPitchList.includes(p));

      if (type === 'Yellow Card' || type === 'Red Card') {
        let onPitchHtml = '';
        onPitchList.forEach(p => { onPitchHtml += `<option value="${p}">${p}</option>`; });
        let benchHtml = '';
        benchList.forEach(p => { benchHtml += `<option value="${p}">${p}</option>`; });
        if (benchList.length > 0) {
          pSelect.innerHTML += `<optgroup label="On Pitch (${onPitchList.length})">${onPitchHtml}</optgroup>`;
          pSelect.innerHTML += `<optgroup label="Substitutes / Bench (${benchList.length})">${benchHtml}</optgroup>`;
        } else {
          pSelect.innerHTML += onPitchHtml;
        }
      } else if (type === 'Goal' || type === 'Own Goal' || type === 'Shootout Goal' || type === 'Shootout Miss') {
        onPitchList.forEach(p => {
          pSelect.innerHTML += `<option value="${p}">${p}</option>`;
          aSelect.innerHTML += `<option value="${p}">${p}</option>`;
        });
        if (benchList.length > 0) {
          let benchOpt = '';
          benchList.forEach(p => { benchOpt += `<option value="${p}">${p}</option>`; });
          pSelect.innerHTML += `<optgroup label="Other Players">${benchOpt}</optgroup>`;
          aSelect.innerHTML += `<optgroup label="Other Players">${benchOpt}</optgroup>`;
        }
      }

      // Outgoing player: on pitch (fallback to all)
      const outList = onPitchList.length > 0 ? onPitchList : all;
      outList.forEach(p => { outSelect.innerHTML += `<option value="${p}">${p}</option>`; });

      // Incoming subs: bench players, or fallback to all
      const incomingList = benchList.length > 0 ? benchList : all;
      incomingList.forEach(p => { inSelect.innerHTML += `<option value="${p}">${p}</option>`; });
    }

    // Show/hide groups
    document.getElementById('scorerGroup').style.display = type === 'Substitution' ? 'none' : 'block';
    document.getElementById('assistGroup').style.display = type === 'Goal' ? 'block' : 'none';
    document.getElementById('penaltyGroup').style.display = type === 'Goal' ? 'flex' : 'none';
    document.getElementById('subGroup').style.display = type === 'Substitution' ? 'block' : 'none';
    document.getElementById('subInGroup').style.display = type === 'Substitution' ? 'block' : 'none';

    // Update label text
    const sLabel = document.getElementById('scorerLabel');
    if (type === 'Goal') sLabel.textContent = isExt ? 'Goal Scorer (type name)' : 'Goal Scorer';
    else if (type === 'Own Goal') sLabel.textContent = 'Own-goal Scorer' + (isExt ? ' (type name)' : ' (' + eventTeamName + ')');
    else if (type === 'Shootout Goal') sLabel.textContent = isExt ? 'Penalty Shootout Scorer (type name)' : 'Penalty Shootout Scorer';
    else if (type === 'Shootout Miss') sLabel.textContent = isExt ? 'Penalty Shootout Player (type name)' : 'Penalty Shootout Player (Missed)';
    else if (type.includes('Card')) sLabel.textContent = isExt ? 'Player Carded (type name)' : 'Player Carded';
    document.getElementById('eventIsPenalty').checked = false;

    document.getElementById('eventModal').classList.add('active');
}

function closeEventModal() {
    document.getElementById('eventModal').classList.remove('active');
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
}

function appendEventToLog(matchId, type, extra, res) {
  const container = document.getElementById('events-log-' + matchId);
  if (!container) return;

  // Remove "No events recorded yet" notice if present
  const noEv = container.querySelector('div[style*="font-style:italic"]');
  if (noEv) noEv.remove();

  const minEl = document.getElementById('min-' + matchId);
  const minute = (res && res.minute !== undefined) ? res.minute : (minEl ? minEl.textContent.replace("'", "").trim() : "0");
  const eventId = (res && res.eventId) ? res.eventId : ('me' + Date.now());

  let icon = '•';
  let color = '#8BA3B8';
  if (type === 'Goal') { icon = '⚽'; color = '#22c55e'; }
  else if (type === 'Own Goal') { icon = '⚽'; color = '#ef4444'; }
  else if (type === 'Shootout Goal') { icon = '✓'; color = '#22c55e'; }
  else if (type === 'Shootout Miss') { icon = '✕'; color = '#ef4444'; }
  else if (type === 'Yellow Card') { icon = '🟨'; color = '#eab308'; }
  else if (type === 'Red Card') { icon = '🟥'; color = '#ef4444'; }
  else if (type === 'Substitution') { icon = '🔄'; color = '#60a5fa'; }

  const matchTeams = liveMatchTeams[matchId] || {};
  const teamLabel = extra.side === 'home' ? (matchTeams.home || '') : (matchTeams.away || '');

  let innerContent = '';
  if (type === 'Substitution') {
    let subOut = '';
    let subIn = '';
    const raw = extra.playerName || '';
    if (raw.includes('->')) {
      const parts = raw.split('->');
      subOut = parts[0].trim();
      subIn = parts[1].trim();
    } else if (raw.includes('→')) {
      const parts = raw.split('→');
      subOut = parts[0].trim();
      subIn = parts[1].trim();
    } else if (extra.assistName) {
      subOut = extra.assistName.trim();
      subIn = raw.trim();
    } else {
      subIn = raw.trim();
    }

    innerContent = `
      ${subIn ? `<div style="font-size:13px;font-weight:700;color:#22c55e;">↑ IN: <span class="event-subin-text">${escapeHtml(subIn)}</span></div>` : ''}
      ${subOut ? `<div style="font-size:12px;font-weight:600;color:#ef4444;">↓ OUT: <span class="event-subout-text">${escapeHtml(subOut)}</span></div>` : ''}
      <div style="font-size:11px;color:#8BA3B8;margin-top:2px;">${escapeHtml(teamLabel)}</div>
    `;
  } else {
    innerContent = `
      <div class="event-player-text" style="font-size:13.5px;font-weight:700;color:${color};">${escapeHtml(extra.playerName || '')}</div>
      ${extra.assistName ? `<div class="event-assist-text" style="font-size:11px;color:#8BA3B8;">Assist: ${escapeHtml(extra.assistName)}</div>` : '<div class="event-assist-text" style="font-size:11px;color:#8BA3B8;display:none;"></div>'}
      ${(type === 'Shootout Goal' || type === 'Shootout Miss') ? `<div class="event-penalty-text" style="font-size:11px;color:#D2B059;">Penalty shootout · ${type === 'Shootout Goal' ? 'Scored' : 'Missed'}</div>` : (extra.isPenalty ? `<div class="event-penalty-text" style="font-size:11px;color:#D2B059;">(Penalty)</div>` : '')}
      <div style="font-size:11px;color:#8BA3B8;">${escapeHtml(teamLabel)}</div>
    `;
  }

  const row = document.createElement('div');
  row.id = 'event-row-' + eventId;
  row.className = 'event-row';
  row.style = 'display:flex;align-items:center;gap:8px;background:rgba(255,255,255,.04);border-radius:8px;padding:8px 10px;';
  row.innerHTML = `
    <span style="font-size:16px;line-height:1">${icon}</span>
    <div style="flex:1;min-width:0;">
      ${innerContent}
    </div>
    <div style="display:flex;align-items:center;gap:6px;">
      <span class="event-min-text" style="font-size:12px;font-weight:800;color:${color};white-space:nowrap;margin-right:2px;">${minute}'</span>
      <button type="button" class="btn btn-outline btn-xs" title="Edit event" onclick="openEditEventModal('${escapeHtml(eventId)}', '${escapeHtml(matchId)}', '${escapeHtml(type)}', ${parseInt(minute)}, '${escapeHtml(extra.playerName || '')}', '${escapeHtml(extra.assistName || '')}', ${extra.isPenalty ? 1 : 0}, '${escapeHtml(teamLabel)}')" style="padding:3px 6px;">
        <span class="material-icons-round" style="font-size:14px">edit</span>
      </button>
      <button type="button" class="btn btn-outline btn-xs" title="Delete event" onclick="deleteEvent('${escapeHtml(eventId)}', '${escapeHtml(matchId)}', '${escapeHtml(type)}')" style="padding:3px 6px;color:#ef4444;border-color:rgba(239,68,68,0.3);">
        <span class="material-icons-round" style="font-size:14px">delete</span>
      </button>
    </div>
  `;
  container.appendChild(row);
  container.scrollTop = container.scrollHeight;
}

let isSubmittingEvent = false;

function submitEvent(e) {
  e.preventDefault();
  if (isSubmittingEvent) return;

  const matchId = document.getElementById('eventMatchId').value;
  const type = document.getElementById('eventType').value;
  const side = document.getElementById('eventSide').value;
  const teamName = document.getElementById('eventModalTitle').dataset.team;
  const extra = { side, type };

  // Determine which team's roster matters (own goals use opposing team)
  const matchTeams = liveMatchTeams[matchId] || {};
  const eventTeamName = type === 'Own Goal'
    ? (side === 'home' ? matchTeams.away : matchTeams.home)
    : teamName;
  const isExt = Boolean(teamIsExternal[eventTeamName] || (!teamAllPlayers[eventTeamName] || teamAllPlayers[eventTeamName].length === 0));

  let subOutName = '';
  let subInName = '';

  if (type === 'Substitution') {
    if (isExt) {
      subOutName = document.getElementById('eventOutNameText').value.trim();
      subInName  = document.getElementById('eventInNameText').value.trim();
      if (!subOutName || !subInName) { alert('Please type both outgoing and incoming player names.'); return; }
    } else {
      subOutName = document.getElementById('eventOutName').value;
      subInName  = document.getElementById('eventInName').value;
      if (!subOutName || !subInName) { alert('Select both outgoing and incoming players'); return; }
    }
    extra.playerName = `${subOutName} -> ${subInName}`;
    extra.assistName = subOutName;
    extra.isPenalty = 0;
  } else {
    if (isExt) {
      extra.playerName = document.getElementById('eventPlayerNameText').value.trim();
      if (!extra.playerName) { alert('Please type the player name.'); return; }
      extra.assistName = document.getElementById('eventAssistNameText').value.trim();
    } else {
      extra.playerName = document.getElementById('eventPlayerName').value;
      if (!extra.playerName) { alert('Please select a player.'); return; }
      extra.assistName = document.getElementById('eventAssistName').value;
    }
    extra.isPenalty = document.getElementById('eventIsPenalty').checked ? 1 : 0;
  }

  const submitBtn = document.getElementById('saveEventSubmitBtn');
  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.textContent = 'Saving...';
  }
  isSubmittingEvent = true;

  post('add_event', matchId, extra).then(d => {
    if (d.ok) {
      if (type === 'Substitution' && teamName && !isExt) {
        if (teamStarters[teamName]) {
          const idx = teamStarters[teamName].findIndex(p => p.trim() === subOutName.trim());
          if (idx !== -1) {
            teamStarters[teamName][idx] = subInName.trim();
          }
        }
      }
      updateScoreDisplay(matchId, d.home, d.away);
      updateShootoutDisplay(matchId, d.shootoutHome, d.shootoutAway);
      pushTime(matchId);
      closeEventModal();
      // Immediately show the new event in the log with full edit/delete controls
      appendEventToLog(matchId, type, extra, d);
    } else {
      alert(d.msg || 'Error adding event');
    }
  }).catch(err => {
    alert('Network error while saving event. Please try again.');
  }).finally(() => {
    isSubmittingEvent = false;
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.textContent = 'Save Event';
    }
  });
}

function openEditEventModal(eventId, matchId, type, minute, playerName, assistName, isPenalty, teamName) {
  document.getElementById('editEventId').value = eventId;
  document.getElementById('editEventMatchId').value = matchId;
  document.getElementById('editEventType').value = type;
  document.getElementById('editEventTeamName').value = teamName;
  document.getElementById('editEventMinute').value = minute;
  document.getElementById('editEventIsPenalty').checked = isPenalty === 1;

  document.getElementById('editEventModalTitle').textContent = `Edit ${type} - ${teamName || ''}`;

  const isExt = Boolean(teamIsExternal[teamName] || (!teamAllPlayers[teamName] || teamAllPlayers[teamName].length === 0));

  const pSelect = document.getElementById('editEventPlayerSelect');
  const pText   = document.getElementById('editEventPlayerText');
  const aSelect = document.getElementById('editEventAssistSelect');
  const aText   = document.getElementById('editEventAssistText');
  const outSelect = document.getElementById('editEventOutSelect');
  const outText   = document.getElementById('editEventOutText');
  const inSelect  = document.getElementById('editEventInSelect');
  const inText    = document.getElementById('editEventInText');

  if (isExt) {
    // Show text inputs, hide selects
    pSelect.style.display = 'none';  pText.style.display = 'block';
    aSelect.style.display = 'none';  aText.style.display = 'block';
    outSelect.style.display = 'none'; outText.style.display = 'block';
    inSelect.style.display = 'none';  inText.style.display = 'block';

    if (type === 'Substitution') {
      let subOut = '', subIn = '';
      if (playerName.includes('->')) { [subOut, subIn] = playerName.split('->').map(s => s.trim()); }
      else if (playerName.includes('→')) { [subOut, subIn] = playerName.split('→').map(s => s.trim()); }
      else if (assistName) { subOut = assistName.trim(); subIn = playerName.trim(); }
      else { subIn = playerName.trim(); }
      outText.value = subOut;
      inText.value = subIn;
      document.getElementById('editPlayerGroup').style.display = 'none';
      document.getElementById('editAssistGroup').style.display = 'none';
      document.getElementById('editSubGroup').style.display = 'block';
      document.getElementById('editSubInGroup').style.display = 'block';
      document.getElementById('editPenaltyGroup').style.display = 'none';
    } else {
      pText.value = playerName;
      aText.value = assistName || '';
      document.getElementById('editPlayerGroup').style.display = 'block';
      document.getElementById('editAssistGroup').style.display = type === 'Goal' ? 'block' : 'none';
      document.getElementById('editSubGroup').style.display = 'none';
      document.getElementById('editSubInGroup').style.display = 'none';
      document.getElementById('editPenaltyGroup').style.display = type === 'Goal' ? 'flex' : 'none';
      const pLabel = document.getElementById('editPlayerLabel');
      if (type === 'Goal') pLabel.textContent = 'Goal Scorer (type name)';
      else if (type === 'Own Goal') pLabel.textContent = 'Own-goal Scorer (type name)';
      else if (type === 'Shootout Goal') pLabel.textContent = 'Penalty Shootout Scorer (type name)';
      else if (type === 'Shootout Miss') pLabel.textContent = 'Penalty Shootout Player (type name)';
      else if (type.includes('Card')) pLabel.textContent = 'Player Carded (type name)';
      else pLabel.textContent = 'Player (type name)';
    }
  } else {
    // Normal roster mode — hide text inputs, show selects
    pText.style.display = 'none';   pSelect.style.display = 'block';
    aText.style.display = 'none';   aSelect.style.display = 'block';
    outText.style.display = 'none'; outSelect.style.display = 'block';
    inText.style.display = 'none';  inSelect.style.display = 'block';

    const allPlayers = teamAllPlayers[teamName] || [];
    const starters = teamStarters[teamName] || [];
    const playerList = allPlayers.length > 0 ? allPlayers : starters;

    pSelect.innerHTML = '<option value="">Select player from roster...</option>';
    aSelect.innerHTML = '<option value="">None</option>';
    outSelect.innerHTML = '<option value="">Select outgoing player...</option>';
    inSelect.innerHTML = '<option value="">Select incoming player...</option>';

    playerList.forEach(p => {
      pSelect.innerHTML += `<option value="${escapeHtml(p)}">${escapeHtml(p)}</option>`;
      aSelect.innerHTML += `<option value="${escapeHtml(p)}">${escapeHtml(p)}</option>`;
      outSelect.innerHTML += `<option value="${escapeHtml(p)}">${escapeHtml(p)}</option>`;
      inSelect.innerHTML += `<option value="${escapeHtml(p)}">${escapeHtml(p)}</option>`;
    });

    if (playerName && !playerList.includes(playerName) && !playerName.includes('->') && !playerName.includes('→')) {
      pSelect.innerHTML += `<option value="${escapeHtml(playerName)}">${escapeHtml(playerName)} (Current)</option>`;
    }
    if (assistName && !playerList.includes(assistName)) {
      aSelect.innerHTML += `<option value="${escapeHtml(assistName)}">${escapeHtml(assistName)} (Current)</option>`;
    }

    if (type === 'Substitution') {
      let subOut = '', subIn = '';
      if (playerName.includes('->')) { const p = playerName.split('->'); subOut = p[0].trim(); subIn = p[1].trim(); }
      else if (playerName.includes('→')) { const p = playerName.split('→'); subOut = p[0].trim(); subIn = p[1].trim(); }
      else if (assistName) { subOut = assistName.trim(); subIn = playerName.trim(); }
      else { subIn = playerName.trim(); }

      if (subOut && !playerList.includes(subOut)) {
        outSelect.innerHTML += `<option value="${escapeHtml(subOut)}">${escapeHtml(subOut)} (Current)</option>`;
      }
      if (subIn && !playerList.includes(subIn)) {
        inSelect.innerHTML += `<option value="${escapeHtml(subIn)}">${escapeHtml(subIn)} (Current)</option>`;
      }

      outSelect.value = subOut;
      inSelect.value = subIn;

      document.getElementById('editPlayerGroup').style.display = 'none';
      document.getElementById('editAssistGroup').style.display = 'none';
      document.getElementById('editSubGroup').style.display = 'block';
      document.getElementById('editSubInGroup').style.display = 'block';
      document.getElementById('editPenaltyGroup').style.display = 'none';
    } else {
      pSelect.value = playerName;
      aSelect.value = assistName || '';

      document.getElementById('editPlayerGroup').style.display = 'block';
      document.getElementById('editAssistGroup').style.display = type === 'Goal' ? 'block' : 'none';
      document.getElementById('editSubGroup').style.display = 'none';
      document.getElementById('editSubInGroup').style.display = 'none';
      document.getElementById('editPenaltyGroup').style.display = type === 'Goal' ? 'flex' : 'none';

      const pLabel = document.getElementById('editPlayerLabel');
      if (type === 'Goal') pLabel.textContent = 'Goal Scorer (Squad Roster)';
      else if (type === 'Own Goal') pLabel.textContent = 'Own-goal Scorer (Squad Roster)';
      else if (type === 'Shootout Goal') pLabel.textContent = 'Penalty Shootout Scorer (Squad Roster)';
      else if (type === 'Shootout Miss') pLabel.textContent = 'Penalty Shootout Player (Missed)';
      else if (type.includes('Card')) pLabel.textContent = 'Player Carded (Squad Roster)';
      else pLabel.textContent = 'Player (Squad Roster)';
    }
  }

  document.getElementById('editEventModal').classList.add('active');
}

function closeEditEventModal() {
  document.getElementById('editEventModal').classList.remove('active');
}

function submitEditEvent(e) {
  e.preventDefault();
  const eventId = document.getElementById('editEventId').value;
  const matchId = document.getElementById('editEventMatchId').value;
  const minute = document.getElementById('editEventMinute').value;
  const type = document.getElementById('editEventType').value;
  const teamName = document.getElementById('editEventTeamName').value;
  const isPenalty = document.getElementById('editEventIsPenalty').checked ? 1 : 0;

  const isExt = Boolean(teamIsExternal[teamName] || (!teamAllPlayers[teamName] || teamAllPlayers[teamName].length === 0));

  let playerName = '';
  let assistName = '';

  if (type === 'Substitution') {
    let subOut, subIn;
    if (isExt) {
      subOut = document.getElementById('editEventOutText').value.trim();
      subIn  = document.getElementById('editEventInText').value.trim();
      if (!subOut || !subIn) { alert('Please type both outgoing and incoming player names.'); return; }
    } else {
      subOut = document.getElementById('editEventOutSelect').value;
      subIn  = document.getElementById('editEventInSelect').value;
      if (!subOut || !subIn) { alert('Please select both outgoing and incoming players from the roster.'); return; }
    }
    playerName = `${subOut} -> ${subIn}`;
    assistName = subOut;
  } else {
    if (isExt) {
      playerName = document.getElementById('editEventPlayerText').value.trim();
      if (!playerName) { alert('Please type the player name.'); return; }
      assistName = document.getElementById('editEventAssistText').value.trim();
    } else {
      playerName = document.getElementById('editEventPlayerSelect').value;
      if (!playerName) { alert('Please select a player from the roster.'); return; }
      assistName = document.getElementById('editEventAssistSelect').value;
    }
  }

  const btn = document.getElementById('saveEditEventBtn');
  if (btn) { btn.disabled = true; btn.textContent = 'Saving...'; }

  post('update_event', matchId, {
    eventId,
    minute,
    playerName,
    assistName,
    isPenalty
  }).then(d => {
    if (d.ok) {
      closeEditEventModal();
      // Update DOM element directly in real time
      const row = document.getElementById('event-row-' + eventId);
      if (row) {
        const minBadge = row.querySelector('.event-min-text');
        if (minBadge) minBadge.textContent = minute + "'";

        if (type === 'Substitution') {
          let subOut = '';
          let subIn = '';
          if (playerName.includes('->')) {
            const parts = playerName.split('->');
            subOut = parts[0].trim();
            subIn = parts[1].trim();
          } else if (playerName.includes('→')) {
            const parts = playerName.split('→');
            subOut = parts[0].trim();
            subIn = parts[1].trim();
          }
          const subInEl = row.querySelector('.event-subin-text');
          if (subInEl && subIn) subInEl.textContent = subIn;
          const subOutEl = row.querySelector('.event-subout-text');
          if (subOutEl && subOut) subOutEl.textContent = subOut;
        } else {
          const playerDiv = row.querySelector('.event-player-text');
          if (playerDiv) playerDiv.textContent = playerName;

          const assistDiv = row.querySelector('.event-assist-text');
          if (assistDiv) {
            if (assistName) {
              assistDiv.textContent = 'Assist: ' + assistName;
              assistDiv.style.display = 'block';
            } else {
              assistDiv.style.display = 'none';
            }
          }

          const penDiv = row.querySelector('.event-penalty-text');
          if (penDiv) {
            penDiv.style.display = isPenalty ? 'block' : 'none';
          }
        }

        // Update Edit button onclick attributes so subsequent edits have latest values
        const editBtn = row.querySelector('button[title="Edit event"]');
        if (editBtn) {
          editBtn.setAttribute('onclick', `openEditEventModal('${escapeHtml(eventId)}', '${escapeHtml(matchId)}', '${escapeHtml(type)}', ${parseInt(minute)}, '${escapeHtml(playerName)}', '${escapeHtml(assistName)}', ${isPenalty ? 1 : 0}, '${escapeHtml(teamName)}')`);
        }
      }
    } else {
      alert(d.msg || 'Failed to update event');
    }
  }).catch(err => {
    alert('Network error while updating event.');
  }).finally(() => {
    if (btn) { btn.disabled = false; btn.textContent = 'Save Changes'; }
  });
}

function deleteEvent(eventId, matchId, type) {
  if (!confirm(`Are you sure you want to delete this ${type} event? If this was a goal, the match score will be adjusted automatically.`)) return;

  post('delete_event', matchId, { eventId }).then(d => {
    if (d.ok) {
      const row = document.getElementById('event-row-' + eventId);
      if (row) row.remove();
      if (d.home !== undefined && d.away !== undefined) {
        updateScoreDisplay(matchId, d.home, d.away);
        updateShootoutDisplay(matchId, d.shootoutHome, d.shootoutAway);
        pushTime(matchId);
      }
    } else {
      alert(d.msg || 'Error deleting event');
    }
  }).catch(err => {
    alert('Network error while deleting event.');
  });
}

// Poll all live match states every 10 seconds to stay in sync
<?php foreach($liveMatches as $m): ?>
setInterval(() => {
  post('get_state', '<?= e($m['id']) ?>').then(d => {
    if (d.ok && d.data) {
      updateScoreDisplay('<?= e($m['id']) ?>', d.data.homeScore, d.data.awayScore);
      updateMinDisplay('<?= e($m['id']) ?>', d.data.minute);
      if (d.data.status !== 'live' || Number(d.data.minute) >= 120) {
        stopAutoTick('<?= e($m['id']) ?>', d.data.status === 'live' ? 'Minute limit reached' : 'Match is no longer live');
      }
      // We don't overwrite phase select dropdown to avoid annoying focus jumps, 
      // but we could if we wanted to.
    }
  });
}, 5000);

// Restore Auto-Tick state
if (localStorage.getItem('autotick_<?= e($m['id']) ?>') === '1') {
  const cb = document.getElementById('autotick-<?= e($m['id']) ?>');
  if (cb) {
    cb.checked = true;
    toggleAutoTick('<?= e($m['id']) ?>', true);
  }
}

<?php endforeach; ?>
</script>

<?php require __DIR__.'/footer.php'; ?>
