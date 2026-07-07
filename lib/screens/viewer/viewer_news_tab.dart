import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/news_detail_screen.dart';

class ViewerNewsTab extends StatelessWidget {
  const ViewerNewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: app.news.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final n = app.news[i];
            return InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NewsDetailScreen(article: n))),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NasaColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      child: SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: Image.network(
                          newsImageUrl(i),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: NasaColors.pitch.withValues(alpha: 0.1),
                            child: const Center(
                              child: Icon(Icons.image_outlined,
                                  color: NasaColors.pitch, size: 34),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusChip(
                              label: n.category, color: NasaColors.pitch),
                          const SizedBox(height: 8),
                          Text(n.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  height: 1.25)),
                          const SizedBox(height: 6),
                          Text(n.summary,
                              style: const TextStyle(
                                  color: NasaColors.slate,
                                  fontSize: 12.5,
                                  height: 1.3)),
                          const SizedBox(height: 8),
                          Text(formatShortDate(n.date),
                              style: const TextStyle(
                                  fontSize: 11, color: NasaColors.slate)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
