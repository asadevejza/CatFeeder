import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../services/cat_avatar_service.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

class AddCatScreen extends StatefulWidget {
  final Future<int?> Function(String name, CatProfile profile) onSave;

  final Cat? existingCat;
  final CatProfile? existingProfile;

  final Future<bool> Function(
    int catId,
    String name,
    CatProfile profile,
  )? onUpdate;

  final Future<bool> Function()? onDelete;

  const AddCatScreen({
    super.key,
    required this.onSave,
    this.existingCat,
    this.existingProfile,
    this.onUpdate,
    this.onDelete,
  });

  @override
  State<AddCatScreen> createState() => _AddCatScreenState();
}

class _AddCatScreenState extends State<AddCatScreen> {
  late final TextEditingController nameController;
  late final TextEditingController ageController;
  late final TextEditingController weightController;
  late final TextEditingController breedController;
  late final TextEditingController goalController;

  late String gender;

  Uint8List? avatar;
  bool saving = false;

  bool get edit => widget.existingCat != null;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.existingCat?.name ?? '',
    );

    ageController = TextEditingController(
      text: widget.existingProfile?.ageYears.toString() ?? '',
    );

    weightController = TextEditingController(
      text: widget.existingProfile?.weightKg.toString() ??
          widget.existingCat?.weightKg?.toString() ??
          '',
    );

    breedController = TextEditingController(
      text: widget.existingProfile?.breed ??
          widget.existingCat?.breed ??
          '',
    );

    goalController = TextEditingController(
      text: (
        widget.existingProfile?.dailyGoalGrams ??
        int.tryParse(widget.existingCat?.goals ?? '') ??
        200
      ).toString(),
    );

    gender = widget.existingProfile?.gender ??
        (widget.existingCat?.sex?.toLowerCase() == 'female'
            ? 'Ženka'
            : 'Mužjak');

    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final cat = widget.existingCat;

    if (cat == null) {
      return;
    }

    try {
      final bytes = await CatAvatarService.getAvatarBytes(cat.id);

      if (!mounted) {
        return;
      }

      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          avatar = bytes;
        });
      }
    } catch (_) {
      // Ako nema slike ili backend ne vrati sliku,
      // ostavljamo default avatar.
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Dodaj fotografiju mačke',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Odaberi fotografiju iz galerije ili napravi novu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 18),

                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  leading: _sourceIcon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text(
                    'Galerija',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Odaberi postojeću fotografiju',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      ImageSource.gallery,
                    );
                  },
                ),

                const SizedBox(height: 4),

                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  leading: _sourceIcon(
                    Icons.camera_alt_outlined,
                  ),
                  title: const Text(
                    'Kamera',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Napravi novu fotografiju',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      ImageSource.camera,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final picker = ImagePicker();

      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 95,
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        return;
      }

      setState(() {
        avatar = bytes;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ne mogu otvoriti fotografiju: $e',
          ),
        ),
      );
    }
  }

  Widget _sourceIcon(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: AppColors.primary,
      ),
    );
  }

  bool get valid {
    final age = int.tryParse(
      ageController.text.trim(),
    );

    final weight = double.tryParse(
      weightController.text.trim().replaceAll(',', '.'),
    );

    final goal = int.tryParse(
      goalController.text.trim(),
    );

    return nameController.text.trim().isNotEmpty &&
        age != null &&
        age >= 0 &&
        weight != null &&
        weight > 0 &&
        goal != null &&
        goal > 0;
  }

  Future<void> _save() async {
    if (!valid || saving) {
      return;
    }

    setState(() {
      saving = true;
    });

    final parsedAge = int.parse(
      ageController.text.trim(),
    );

    final parsedWeight = double.parse(
      weightController.text.trim().replaceAll(',', '.'),
    );

    final parsedGoal = int.parse(
      goalController.text.trim(),
    );

    final profile = CatProfile(
      gender: gender,
      breed: breedController.text.trim().isEmpty
          ? 'Domaća kratkodlaka'
          : breedController.text.trim(),
      ageYears: parsedAge,
      weightKg: parsedWeight,
      dailyGoalGrams: parsedGoal,
    );

    bool success = false;
    int? createdCatId;

    try {
      if (edit) {
        success = await widget.onUpdate?.call(
              widget.existingCat!.id,
              nameController.text.trim(),
              profile,
            ) ??
            false;

        if (success &&
            avatar != null &&
            avatar!.isNotEmpty) {
          try {
            await CatAvatarService.setAvatarBytes(
              widget.existingCat!.id,
              avatar!,
            );
          } catch (_) {
            // Profil se ipak može sačuvati i ako upload slike padne.
          }
        }
      } else {
        createdCatId = await widget.onSave(
          nameController.text.trim(),
          profile,
        );

        success =
            createdCatId != null && createdCatId! > 0;

        if (success &&
            createdCatId != null &&
            avatar != null &&
            avatar!.isNotEmpty) {
          try {
            await CatAvatarService.setAvatarBytes(
              createdCatId,
              avatar!,
            );
          } catch (_) {
            // Mačka je kreirana čak i ako upload slike ne uspije.
          }
        }
      }
    } catch (_) {
      success = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      saving = false;
    });

    if (success) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit
              ? AppStrings.t('save_changes_failed')
              : AppStrings.t('add_cat_failed'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    weightController.dispose();
    breedController.dispose();
    goalController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            28,
          ),
          children: [
            // HEADER
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                  ),
                ),

                const SizedBox(width: 2),

                Text(
                  edit ? 'Uredi mačku' : 'Dodaj mačku',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // AVATAR
            Center(
              child: GestureDetector(
                onTap: saving ? null : _pickImage,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryLight,
                            AppColors.primary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primary.withOpacity(.16),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: AppColors.tint50,
                          child: avatar == null
                              ? const Center(
                                  child: Text(
                                    '🐈',
                                    style: TextStyle(
                                      fontSize: 42,
                                    ),
                                  ),
                                )
                              : Image.memory(
                                  avatar!,
                                  width: 98,
                                  height: 98,
                                  fit: BoxFit.cover,
                                  filterQuality:
                                      FilterQuality.high,
                                  gaplessPlayback: true,
                                ),
                        ),
                      ),
                    ),

                    // CAMERA BUTTON
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                avatar == null
                    ? 'Dodaj fotografiju'
                    : 'Promijeni fotografiju',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // NAME
            _label('Ime mačke'),

            const SizedBox(height: 8),

            _field(
              controller: nameController,
              hint: 'npr. Bella',
            ),

            const SizedBox(height: 22),

            // GENDER
            _label('Spol'),

            const SizedBox(height: 8),

            Row(
              children: [
                _gender(
                  'Mužjak',
                  Icons.male_rounded,
                ),
                const SizedBox(width: 12),
                _gender(
                  'Ženka',
                  Icons.female_rounded,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // AGE + WEIGHT
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _label('Godine'),

                      const SizedBox(height: 8),

                      _field(
                        controller: ageController,
                        hint: '2',
                        keyboardType:
                            TextInputType.number,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _label('Težina (kg)'),

                      const SizedBox(height: 8),

                      _field(
                        controller: weightController,
                        hint: '4.5',
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // BREED
            _label('Rasa'),

            const SizedBox(height: 8),

            _field(
              controller: breedController,
              hint: 'Domaća kratkodlaka',
            ),

            const SizedBox(height: 22),

            // DAILY FOOD GOAL
            _label('Dnevni cilj hrane'),

            const SizedBox(height: 8),

            _field(
              controller: goalController,
              hint: '200',
              keyboardType: TextInputType.number,
              suffix: 'g',
            ),

            const SizedBox(height: 30),

            // SAVE BUTTON
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed:
                    valid && !saving ? _save : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        edit
                            ? 'Sačuvaj promjene'
                            : 'Sačuvaj',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),

            // DELETE BUTTON
            if (edit && widget.onDelete != null) ...[
              const SizedBox(height: 8),

              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        final confirmed =
                            await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text(
                                'Obriši mačku?',
                              ),
                              content: const Text(
                                'Ova radnja se ne može poništiti.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                      false,
                                    );
                                  },
                                  child: const Text(
                                    'Odustani',
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                      true,
                                    );
                                  },
                                  style:
                                      FilledButton.styleFrom(
                                    backgroundColor:
                                        AppColors.danger,
                                  ),
                                  child: const Text(
                                    'Obriši',
                                  ),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed != true) {
                          return;
                        }

                        try {
                          final ok =
                              await widget.onDelete!();

                          if (!mounted) {
                            return;
                          }

                          if (ok) {
                            Navigator.pop(
                              context,
                              true,
                            );
                          } else {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Brisanje mačke nije uspjelo.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (!mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Greška pri brisanju: $e',
                              ),
                            ),
                          );
                        }
                      },
                child: const Text(
                  'Obriši mačku',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) {
        setState(() {});
      },
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.cardBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.cardBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _gender(
    String value,
    IconData icon,
  ) {
    final selected = gender == value;

    return Expanded(
      child: InkWell(
        onTap: saving
            ? null
            : () {
                setState(() {
                  gender = value;
                });
              },
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          height: 78,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.tint50
                : Colors.white,
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.cardBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),

              const SizedBox(height: 5),

              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}