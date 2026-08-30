import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/brand.dart';
import '../../core/config/api_config.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../auth/auth_scope.dart';
import '../family/family_scope.dart';
import '../map/member_sheet.dart';

/// Avatar cliquable : galerie ou appareil photo, puis POST /auth/me/photo.
class ProfilePhotoButton extends StatelessWidget {
  const ProfilePhotoButton({super.key, required this.user, this.radius = 40});

  final UserAccount user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('profile-avatar'),
        customBorder: const CircleBorder(),
        onTap: auth.isBusy ? null : () => _pickAndUpload(context),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ProfileAvatar(name: user.fullName, photoUrl: user.photoUrl, radius: radius),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: CityCareBrand.violet,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('profile-photo-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galerie'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                key: const Key('profile-photo-camera'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Appareil photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !context.mounted) {
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !context.mounted) {
      return;
    }
    final auth = AuthScope.of(context);
    final ok = await auth.uploadPhoto(picked.path);
    if (!context.mounted) {
      return;
    }
    if (ok) {
      final photoUrl = auth.user?.photoUrl;
      if (auth.user?.role == UserRole.young) {
        FamilyScope.of(context).applyYoungPhotoUrl(photoUrl);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour')),
      );
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }
}

/// Pastille : NetworkImage si [photoUrl], sinon initiales. Pas de photo inventée.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.photoUrl, this.radius = 22});

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.resolveMediaUrl(photoUrl);
    final initials = memberInitials(name);
    if (resolved != null && resolved.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: CityCareBrand.lavender,
        backgroundImage: NetworkImage(resolved),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: CityCareBrand.lavender,
      foregroundColor: CityCareBrand.violet,
      child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
