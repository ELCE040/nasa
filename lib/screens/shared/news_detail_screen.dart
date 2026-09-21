import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsArticle article;
  const NewsDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final hasImage = article.imageUrl != null && article.imageUrl!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: hasImage ? 260 : 0,
            pinned: true,
            actions: const [RoleSwitcherButton()],
            title: const Text('News'),
            flexibleSpace: hasImage
                ? FlexibleSpaceBar(
                    background: Image.network(
                      ApiService.resolveUrl(article.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: NasaColors.pitch),
                    ),
                    collapseMode: CollapseMode.parallax,
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusChip(label: article.category, color: NasaColors.pitch),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 21, height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${article.author} · ${formatShortDate(article.date)}',
                    style: const TextStyle(color: NasaColors.slate, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    article.body,
                    style: const TextStyle(fontSize: 14.5, height: 1.65),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
