import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'video_upload_dialog.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String playerId;
  final UserRole viewAs;
  const PlayerProfileScreen(
      {super.key, required this.playerId, required this.viewAs});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final app = AppState.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final player = app.playerById(widget.playerId);
        if (player == null) {
          return const Scaffold(body: Center(child: Text('Player not found')));
        }
        final isScoutOrTeam =
            widget.viewAs == UserRole.scout || widget.viewAs == UserRole.team;
        final isTeam = widget.viewAs == UserRole.team;
        final clips = app.videoClipsForPlayer(player.id);
        final injuries = app.injuriesForPlayer(player.id);
        final attendanceRecords = app.attendanceForPlayer(player.id);
        final disciplinaryRecords = app.disciplinaryForPlayer(player.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(player.name),
            actions: [
              if (widget.viewAs == UserRole.scout)
                IconButton(
                  icon: Icon(
                    app.isWatchlisted(player.id)
                        ? Icons.bookmark
                        : Icons.bookmark_outline,
                  ),
                  tooltip: 'Watchlist',
                  onPressed: () {
                    app.toggleWatchlist(player);
                    showNasaSnack(
                      context,
                      app.isWatchlisted(player.id)
                          ? 'Added ${player.name} to your watchlist'
                          : 'Removed ${player.name} from your watchlist',
                    );
                  },
                ),
              const RoleSwitcherButton(),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _Header(player: player),
              _StatsRow(player: player),
              if (isScoutOrTeam) _ValuationCard(player: player),
              _BioCard(player: player),
              _VideoSection(player: player, clips: clips, canUpload: isTeam),
              if (isScoutOrTeam)
                _InjurySection(
                    player: player, injuries: injuries, canEdit: isTeam),
              if (isTeam)
                _AttendanceSection(player: player, records: attendanceRecords),
              if (isScoutOrTeam)
                _DisciplinarySection(
                    records: disciplinaryRecords, canEdit: isTeam),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Player player;
  const _Header({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NasaColors.pitch,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          InitialsAvatar(
            text: player.name,
            radius: 34,
            background: Colors.white,
            foreground: NasaColors.pitch,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${player.jerseyNumber} · ${player.position} · Age ${player.age}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(player.teamName),
                      backgroundColor: Colors.white,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(player.wardName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Player player;
  const _StatsRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NasaColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          StatPill(label: 'Apps', value: '${player.appearances}'),
          StatPill(label: 'Goals', value: '${player.goals}'),
          StatPill(label: 'Assists', value: '${player.assists}'),
          if (player.position == 'Goalkeeper')
            StatPill(label: 'Clean Sheets', value: '${player.cleanSheets}')
          else
            StatPill(
                label: 'Yellow/Red',
                value: '${player.yellowCards}/${player.redCards}'),
        ],
      ),
    );
  }
}

class _ValuationCard extends StatelessWidget {
  final Player player;
  const _ValuationCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NasaColors.sun.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NasaColors.sun.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: NasaColors.pitchDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated market value',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: NasaColors.slate,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  formatMwk(player.marketValueMwk),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: NasaColors.ink),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline,
                size: 18, color: NasaColors.slate),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('How is this calculated?'),
                  content: const Text(
                    'A transparent algorithm combining goals, assists, appearances, '
                    'clean sheets and an age-curve multiplier, less a small penalty for '
                    'disciplinary cards. Scouts and clubs see the same formula — no black box.',
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BioCard extends StatelessWidget {
  final Player player;
  const _BioCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text(player.bio,
              style: const TextStyle(color: NasaColors.slate, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WardTag(
                  label: '${player.preferredFoot}-footed',
                  icon: Icons.sports_soccer),
              WardTag(
                  label: '${player.heightM.toStringAsFixed(2)} m',
                  icon: Icons.height),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoSection extends StatelessWidget {
  final Player player;
  final List<VideoClip> clips;
  final bool canUpload;
  const _VideoSection(
      {required this.player, required this.clips, required this.canUpload});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Highlight clips',
          actionLabel: canUpload ? 'Upload' : null,
          onAction: canUpload
              ? () => showVideoUploadDialog(context, presetPlayerId: player.id)
              : null,
        ),
        if (clips.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No clips uploaded yet.',
                style: TextStyle(color: NasaColors.slate)),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: clips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final c = clips[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => showNasaSnack(
                      context, 'Playing "${c.title}" (${c.durationSeconds}s)'),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NasaColors.ink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.play_circle_fill,
                            color: NasaColors.sun, size: 26),
                        const Spacer(),
                        Text(
                          c.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700),
                        ),
                        Text('${c.durationSeconds}s',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _InjurySection extends StatelessWidget {
  final Player player;
  final List<InjuryRecord> injuries;
  final bool canEdit;
  const _InjurySection(
      {required this.player, required this.injuries, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Medical & injury registry',
          actionLabel: canEdit ? 'Log injury' : null,
          onAction:
              canEdit ? () => _showLogInjuryDialog(context, player.id) : null,
        ),
        if (injuries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No injuries on record — clean history.',
                style: TextStyle(color: NasaColors.slate)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: injuries.map((i) {
                final color = i.status == InjuryStatus.fit
                    ? NasaColors.pitch
                    : NasaColors.earth;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NasaColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.injuryType,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              '${formatShortDate(i.date)} · ${i.recoveryDays} day recovery',
                              style: const TextStyle(
                                  fontSize: 11.5, color: NasaColors.slate),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label:
                            i.status == InjuryStatus.fit ? 'Fit' : 'Recovering',
                        color: color,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showLogInjuryDialog(BuildContext context, String playerId) {
    final typeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final recoveryCtrl = TextEditingController(text: '7');
    InjurySeverity severity = InjurySeverity.minor;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Log injury'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: typeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Injury type')),
                const SizedBox(height: 12),
                DropdownButtonFormField<InjurySeverity>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: InjurySeverity.values
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => severity = v ?? severity),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: recoveryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Expected recovery (days)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (typeCtrl.text.trim().isEmpty) return;
                AppState.instance.addInjuryRecord(
                  playerId: playerId,
                  injuryType: typeCtrl.text.trim(),
                  severity: severity,
                  recoveryDays: int.tryParse(recoveryCtrl.text) ?? 7,
                  notes: notesCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                showNasaSnack(context, 'Injury record saved');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  final Player player;
  final List<AttendanceRecord> records;
  const _AttendanceSection({required this.player, required this.records});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'School attendance',
          actionLabel: 'Log week',
          onAction: () => _showLogAttendanceDialog(context, player.id),
        ),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No attendance logged yet.',
                style: TextStyle(color: NasaColors.slate)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: records.map((a) {
                final pct = (a.rate * 100).round();
                final color = pct >= 80 ? NasaColors.pitch : NasaColors.earth;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NasaColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Week of ${formatShortDate(a.weekOf)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('Logged by ${a.loggedBy}',
                                style: const TextStyle(
                                    fontSize: 11.5, color: NasaColors.slate)),
                          ],
                        ),
                      ),
                      StatusChip(
                          label: '${a.daysPresent}/${a.daysTotal} days · $pct%',
                          color: color),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showLogAttendanceDialog(BuildContext context, String playerId) {
    final presentCtrl = TextEditingController(text: '5');
    final totalCtrl = TextEditingController(text: '5');
    final loggedByCtrl = TextEditingController(text: 'Coach');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log school attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: presentCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Days present'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'School days this week'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: loggedByCtrl,
              decoration: const InputDecoration(labelText: 'Logged by'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              AppState.instance.logAttendance(
                playerId: playerId,
                daysPresent: int.tryParse(presentCtrl.text) ?? 0,
                daysTotal: int.tryParse(totalCtrl.text) ?? 5,
                loggedBy: loggedByCtrl.text.trim().isEmpty
                    ? 'Coach'
                    : loggedByCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              showNasaSnack(context, 'Attendance logged');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _DisciplinarySection extends StatelessWidget {
  final List<DisciplinaryRecord> records;
  final bool canEdit;
  const _DisciplinarySection({required this.records, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Disciplinary log'),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No cards or fines on record.',
                style: TextStyle(color: NasaColors.slate)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: records.map((d) {
                final color = d.cardType == CardType.red
                    ? NasaColors.earth
                    : NasaColors.sun;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NasaColors.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 14,
                        height: 18,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.reason,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(d.matchLabel,
                                style: const TextStyle(
                                    fontSize: 11.5, color: NasaColors.slate)),
                            Text(formatShortDate(d.date),
                                style: const TextStyle(
                                    fontSize: 11.5, color: NasaColors.slate)),
                            if (d.fineAmount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: StatusChip(
                                  label: d.finePaid
                                      ? '${formatMwk(d.fineAmount)} paid'
                                      : '${formatMwk(d.fineAmount)} unpaid',
                                  color: d.finePaid
                                      ? NasaColors.pitch
                                      : NasaColors.earth,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
