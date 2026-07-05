import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/feeding_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/inline_status.dart';
import '../widgets/pet_avatar.dart';

/// Autosaves as you go — no Save button. Text fields save shortly after you
/// stop typing (debounced, so it's not hammering storage on every
/// keystroke); the photo saves the instant you pick one.
class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  late TextEditingController petNameController;
  late TextEditingController breedController;
  late TextEditingController weightController;
  late TextEditingController ageController;

  Timer? _debounce;
  ActionStatus _saveStatus = ActionStatus.idle;

  @override
  void initState() {
    super.initState();
    final provider = context.read<FeedingProvider>();
    petNameController = TextEditingController(text: provider.petName);
    breedController = TextEditingController(text: provider.breed);
    weightController = TextEditingController(text: provider.weight);
    ageController = TextEditingController(text: provider.age);

    for (final controller in [petNameController, breedController, weightController, ageController]) {
      controller.addListener(_scheduleSave);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    petNameController.dispose();
    breedController.dispose();
    weightController.dispose();
    ageController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saveStatus = ActionStatus.loading);
    await context.read<FeedingProvider>().updatePetProfile(
          petName: petNameController.text,
          breed: breedController.text,
          weight: weightController.text,
          age: ageController.text,
        );
    if (!mounted) return;
    setState(() => _saveStatus = ActionStatus.success);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saveStatus = ActionStatus.idle);
    });
  }

  Future<void> _openPhotoPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PhotoPickerSheet(),
    );
    if (result == null || !mounted) return;

    // Photo saves immediately — no waiting for a debounce or a Save button.
    setState(() => _saveStatus = ActionStatus.loading);
    await context.read<FeedingProvider>().updatePetPhoto(result);
    if (!mounted) return;
    setState(() => _saveStatus = ActionStatus.success);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saveStatus = ActionStatus.idle);
    });
  }

  Widget buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.grey,
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(top: 4, bottom: 4),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedingProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.arrow_back, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Pet profile", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: InlineStatusDot(status: _saveStatus)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _openPhotoPicker,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryColor, width: 2),
                          ),
                          child: PetAvatar(photoRef: provider.petPhoto, radius: 45),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    petNameController.text.isEmpty ? "Your pet" : petNameController.text,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text("Active pet profile", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _openPhotoPicker,
                    child: Text(
                      "Change photo",
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "PET INFORMATION",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  "Saves automatically",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            buildField(label: "PET NAME", controller: petNameController, icon: Icons.badge_outlined),
            buildField(label: "BREED", controller: breedController, icon: Icons.category_outlined),

            Row(
              children: [
                Expanded(
                  child: buildField(
                    label: "WEIGHT (KG)",
                    controller: weightController,
                    icon: Icons.fitness_center,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildField(
                    label: "AGE (YEARS)",
                    controller: ageController,
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PhotoPickerSheet extends StatelessWidget {
  const _PhotoPickerSheet();

  Future<void> _pickFrom(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
      if (picked == null) return;
      if (!context.mounted) return;
      Navigator.pop(context, "file:${picked.path}");
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? "Couldn't open the camera. Check the app has camera permission in your phone's Settings."
                : "Couldn't open the gallery. Check the app has photo access in your phone's Settings.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
            ),
            const Text("Change photo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFrom(context, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text("Camera"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFrom(context, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text("Gallery"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "OR PICK AN AVATAR",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: kPetPresetIds.map((id) {
                final color = kPetPresetColors[id]!;
                final emoji = kPetPresetEmojis[id]!;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, "preset:$id"),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        id[0].toUpperCase() + id.substring(1),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
