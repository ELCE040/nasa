import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class PlayerCardScreen extends StatelessWidget {
  final Player player;

  const PlayerCardScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final imageUrl = player.imageUrl != null && player.imageUrl!.trim().isNotEmpty
        ? ApiService.resolveUrl(player.imageUrl!)
        : null;

    return Scaffold(
      backgroundColor: NasaColors.bgDark,
      appBar: AppBar(
        backgroundColor: NasaColors.bgNav,
        title: const Text('Official Player Identity Card'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 340,
                decoration: BoxDecoration(
                  color: NasaColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NasaColors.gold.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: NasaColors.gold.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: const BoxDecoration(
                        color: NasaColors.bgNav,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                        border: Border(
                          bottom: BorderSide(color: NasaColors.red, width: 3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield, color: NasaColors.gold, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  player.teamName,
                                  style: const TextStyle(
                                    color: NasaColors.gold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'NAYSA REGISTERED ATHLETE PASS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Body
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo
                          Container(
                            width: 105,
                            height: 130,
                            decoration: BoxDecoration(
                              color: NasaColors.bgNavy,
                              border: Border.all(color: NasaColors.gold, width: 2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: imageUrl == null
                                ? Center(
                                    child: Text(
                                      player.name.isNotEmpty ? player.name[0] : '?',
                                      style: const TextStyle(
                                        color: NasaColors.gold,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, error, __) {
                                      return const Center(
                                        child: Icon(Icons.broken_image_outlined, size: 40, color: NasaColors.textMuted),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetail('NAME', player.name),
                                _buildDetail('POSITION', player.position.toUpperCase()),
                                Row(
                                  children: [
                                    Expanded(child: _buildDetail('AGE', '${player.age} yrs')),
                                    Expanded(child: _buildDetail('SQUAD NO.', '#${player.jerseyNumber}')),
                                  ],
                                ),
                                _buildDetail('WARD', player.wardName),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: const BoxDecoration(
                        color: NasaColors.bgNavy,
                        border: Border(top: BorderSide(color: NasaColors.border)),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'THE PITCH IS FOR EVERYONE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: NasaColors.gold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Icon(Icons.qr_code, size: 18, color: NasaColors.textMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Export / Share ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NasaColors.gold,
                  foregroundColor: const Color(0xFF070D18),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID Card ready for print & scout verification')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: NasaColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
