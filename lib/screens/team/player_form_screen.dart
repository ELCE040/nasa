import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class PlayerFormScreen extends StatefulWidget {
  final Player? player;
  const PlayerFormScreen({super.key, this.player});
  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _jerseyCtrl = TextEditingController();
  final _heightCtrl = TextEditingController(text: '1.65');
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+265 9');
  String _position = 'Striker';
  String _foot = 'Right';
  bool _uploading = false;
  String? _imageUrl;

  static const _positions = [
    'Goalkeeper',
    'Defender',
    'Midfielder',
    'Winger',
    'Striker'
  ];

  bool get _isEditing => widget.player != null;

  @override
  void initState() {
    super.initState();
    final player = widget.player;
    if (player == null) return;
    _nameCtrl.text = player.name;
    _ageCtrl.text = '${player.age}';
    _jerseyCtrl.text = '${player.jerseyNumber}';
    _heightCtrl.text = '${player.heightM}';
    _bioCtrl.text = player.bio;
    _phoneCtrl.text = player.parentPhone;
    _position = player.position;
    _foot = player.preferredFoot;
    _imageUrl = player.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final team = app.currentTeam;
    if (team == null) return const Scaffold(body: Center(child: Text('Not logged in as team')));
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit player' : 'Add player'),
        actions: const [RoleSwitcherButton()],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${_isEditing ? 'Editing' : 'Registering'} for ${team.name} (${team.wardName})',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    validator: (v) =>
                        (int.tryParse(v ?? '') == null) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _jerseyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Jersey #'),
                    validator: (v) =>
                        (int.tryParse(v ?? '') == null) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _position,
              decoration: const InputDecoration(labelText: 'Position'),
              items: _positions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _position = v ?? _position),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _foot,
                    decoration:
                        const InputDecoration(labelText: 'Preferred foot'),
                    items: const [
                      DropdownMenuItem(value: 'Right', child: Text('Right')),
                      DropdownMenuItem(value: 'Left', child: Text('Left')),
                    ],
                    onChanged: (v) => setState(() => _foot = v ?? _foot),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (m)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration:
                  const InputDecoration(labelText: 'Emergency contact phone'),
              validator: (v) =>
                  (v == null || v.trim().length < 6) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Short bio'),
            ),
            const SizedBox(height: 12),
            if (_imageUrl != null)
              Center(
                child: Image.network(
                  ApiService.resolveUrl(_imageUrl!),
                  height: 100,
                  errorBuilder: (_, error, __) {
                    debugPrint('[IMAGE DISPLAY] Edit preview failed for $_imageUrl: $error');
                    return const Icon(Icons.broken_image_outlined, size: 48);
                  },
                ),
              ),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: Text(_imageUrl == null ? 'Add photo' : 'Change photo'),
                onPressed: _uploading ? null : _chooseAndUploadPhoto,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _uploading ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _uploading = true);
                  try {
                    if (_isEditing) {
                      await app.updatePlayerProfile(
                        existing: widget.player!,
                        name: _nameCtrl.text.trim(),
                        age: int.parse(_ageCtrl.text),
                        position: _position,
                        jerseyNumber: int.parse(_jerseyCtrl.text),
                        preferredFoot: _foot,
                        heightM: double.tryParse(_heightCtrl.text) ?? 1.65,
                        bio: _bioCtrl.text.trim().isEmpty ? 'Player profile' : _bioCtrl.text.trim(),
                        parentPhone: _phoneCtrl.text.trim(),
                        imageUrl: _imageUrl,
                      );
                    } else {
                      await app.addPlayer(
                        name: _nameCtrl.text.trim(),
                        age: int.parse(_ageCtrl.text),
                        position: _position,
                        teamId: team.id,
                        jerseyNumber: int.parse(_jerseyCtrl.text),
                        preferredFoot: _foot,
                        heightM: double.tryParse(_heightCtrl.text) ?? 1.65,
                        bio: _bioCtrl.text.trim().isEmpty ? 'New squad member.' : _bioCtrl.text.trim(),
                        parentPhone: _phoneCtrl.text.trim(),
                        imageUrl: _imageUrl,
                      );
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      showNasaSnack(context, _isEditing
                          ? '${_nameCtrl.text.trim()} updated'
                          : '${_nameCtrl.text.trim()} added to the roster');
                    }
                  } catch (error) {
                    if (mounted) showNasaSnack(context, 'Could not add player. Please try again later.');
                  } finally {
                    if (mounted) setState(() => _uploading = false);
                  }
                },
                child: _uploading
                    ? const CircularProgressIndicator()
                    : Text(_isEditing ? 'Save changes' : 'Register player'),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626), // Stark solid red
                    side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                    backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20),
                  label: const Text(
                    'Delete Player',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: _uploading ? null : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: NasaColors.bgCard,
                        title: const Text('Delete Player?'),
                        content: Text('Are you sure you want to remove ${widget.player!.name} from your squad? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: NasaColors.textMuted)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      Navigator.pop(context);
                      showNasaSnack(context, '${widget.player!.name} deleted from squad.');
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chooseAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              subtitle: const Text('Use the camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Select an existing image'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null || !mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop player photo',
            toolbarColor: const Color(0xFF12395D),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFD6B34D),
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: const [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
            ],
          ),
        ],
      );
      if (cropped == null || !mounted) return;

      setState(() => _uploading = true);
      final imageUrl = await ApiService.uploadPlayerImage(XFile(cropped.path));
      if (!mounted) return;
      setState(() => _imageUrl = imageUrl);
      showNasaSnack(context, 'Photo uploaded successfully.');
    } catch (error) {
      debugPrint('[PLAYER PHOTO] Camera/gallery/crop/upload failed: $error');
      if (mounted) {
        showNasaSnack(
          context,
          'Could not prepare the photo: $error',
          success: false,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
