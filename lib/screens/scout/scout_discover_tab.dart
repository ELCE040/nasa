import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/player_profile_screen.dart';

class ScoutDiscoverTab extends StatefulWidget {
  const ScoutDiscoverTab({super.key});
  @override
  State<ScoutDiscoverTab> createState() => _ScoutDiscoverTabState();
}

class _ScoutDiscoverTabState extends State<ScoutDiscoverTab> {
  String _query = '';
  String _position = 'All';
  String _ward = 'All';

  static const _positions = ['All', 'Goalkeeper', 'Defender', 'Midfielder', 'Winger', 'Striker'];

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final wards = ['All', ...app.wards.map((w) => w.name)];
        var players = app.players.where((p) {
          final matchesQuery = _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
          final matchesPosition = _position == 'All' || p.position == _position;
          final matchesWard = _ward == 'All' || p.wardName == _ward;
          return matchesQuery && matchesPosition && matchesWard;
        }).toList();
        players.sort((a, b) => b.marketValueMwk.compareTo(a.marketValueMwk));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search players by name',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _positions.map((p) {
                  final selected = _position == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p),
                      selected: selected,
                      onSelected: (_) => setState(() => _position = p),
                      selectedColor: NasaColors.pitch,
                      labelStyle: TextStyle(color: selected ? Colors.white : NasaColors.ink, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<String>(
                  value: _ward,
                  underline: const SizedBox.shrink(),
                  items: wards.map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _ward = v ?? _ward),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: players.isEmpty
                  ? const EmptyState(icon: Icons.search_off, title: 'No players found', message: 'Try a different name, position or ward.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      itemCount: players.length,
                      itemBuilder: (context, i) {
                        final p = players[i];
                        final watchlisted = app.isWatchlisted(p.id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: NasaColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: NasaColors.border),
                          ),
                          child: ListTile(
                            leading: InitialsAvatar(text: p.name, radius: 20, imageUrl: p.imageUrl),
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                            subtitle: Text('${p.position} · ${p.teamName} · Age ${p.age}', style: const TextStyle(fontSize: 12, color: NasaColors.textMuted)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatMwk(p.marketValueMwk), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: NasaColors.gold)),
                                const SizedBox(height: 2),
                                Icon(
                                  watchlisted ? Icons.bookmark : Icons.bookmark_outline,
                                  size: 18,
                                  color: watchlisted ? NasaColors.gold : NasaColors.textMuted,
                                ),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PlayerProfileScreen(playerId: p.id, viewAs: UserRole.scout)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
