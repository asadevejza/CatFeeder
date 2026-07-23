import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../api_config.dart';
import '../models/cat.dart';
import '../services/cat_avatar_service.dart';

class ManualFeedingScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  final bool isLoadingCats;
  final int? selectedCatId;
  final int feedTrigger;
  final void Function(int catId) onSelectCat;
  final Future<bool> Function(String name) onAddCat;
  final Future<bool> Function(int id, String newName) onEditCat;
  final Future<bool> Function(int id) onDeleteCat;
  final void Function(int grams) onFedSuccess;

  const ManualFeedingScreen({
    super.key,
    required this.baseUrl,
    required this.cats,
    required this.isLoadingCats,
    required this.selectedCatId,
    required this.feedTrigger,
    required this.onSelectCat,
    required this.onAddCat,
    required this.onEditCat,
    required this.onDeleteCat,
    required this.onFedSuccess,
  });

  @override
  State<ManualFeedingScreen> createState() => _ManualFeedingScreenState();
}


class _ManualFeedingScreenState extends State<ManualFeedingScreen> {
  int selectedPortion = 50;
  bool isFeeding = false;

  // catId -> lokalna putanja do slike na telefonu (samo za mačke koje je imaju)
  Map<int, String> avatarPaths = {};

  @override
  void initState() {
    super.initState();
    loadAvatars();
  }

  @override
  void didUpdateWidget(covariant ManualFeedingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cats.length != widget.cats.length) {
      loadAvatars();
    }
  }

  Future<void> loadAvatars() async {
    final Map<int, String> loaded = {};
    for (final cat in widget.cats) {
      final path = await CatAvatarService.getAvatarPath(cat.id);
      if (path != null) loaded[cat.id] = path;
    }
    if (!mounted) return;
    setState(() => avatarPaths = loaded);
  }

  Future<void> pickAndSetAvatar(Cat cat, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked == null) return;

      final path = await CatAvatarService.setAvatar(cat.id, picked);
      if (!mounted) return;
      setState(() => avatarPaths[cat.id] = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška pri biranju slike: $e')));
    }
  }

  Future<void> feedCat() async {
    if (widget.selectedCatId == null) return;
    setState(() => isFeeding = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/feedinglogs'),
        headers: apiHeaders(withJsonBody: true),
        body: json.encode({
          'catId': widget.selectedCatId,
          'portionGrams': selectedPortion,
          'triggeredBy': 'Manual (App)',
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 201 || response.statusCode == 200) {
        widget.onFedSuccess(selectedPortion);
        final catName = widget.cats.firstWhere((c) => c.id == widget.selectedCatId).name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uspješno ispušteno $selectedPortion g hrane za $catName! 🐾')),
        );
      } else {
        throw Exception('Greška na serveru');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspješno povezivanje: $e')),
      );
    } finally {
      if (mounted) setState(() => isFeeding = false);
    }
  }

  Future<void> showAddCatDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nova mačka'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ime mačke, npr. Bella'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await widget.onAddCat(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '$result je dodana! 🐱' : 'Nije uspjelo dodavanje mačke')),
      );
    }
  }

  Future<void> showManageCatDialog(Cat cat) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(cat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.lightBlue),
              title: const Text('Slikaj'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.lightBlue),
              title: const Text('Izaberi iz galerije'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.lightBlue),
              title: const Text('Preimenuj'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Obriši mačku'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == 'camera') {
      await pickAndSetAvatar(cat, ImageSource.camera);
      return;
    }
    if (action == 'gallery') {
      await pickAndSetAvatar(cat, ImageSource.gallery);
      return;
    }

    if (!mounted || action == null) return;

    if (action == 'edit') {
      final controller = TextEditingController(text: cat.name);
      final newName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Preimenuj mačku'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Sačuvaj'),
            ),
          ],
        ),
      );
      if (newName != null && newName.isNotEmpty && mounted) {
        final success = await widget.onEditCat(cat.id, newName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Ime promijenjeno! ✏️' : 'Nije uspjelo preimenovanje')),
        );
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Obrisati ${cat.name}?'),
          content: const Text('Ovo će trajno obrisati i cijelu njenu historiju hranjenja i sve rasporede. Ne može se poništiti.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Obriši', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await CatAvatarService.removeAvatar(cat.id);
        final success = await widget.onDeleteCat(cat.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '${cat.name} je obrisana.' : 'Brisanje nije uspjelo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCats = widget.cats.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Ručno hranjenje')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CatMoodWidget(feedTrigger: widget.feedTrigger),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Text('Izaberi mačku', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: showAddCatDialog,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Dodaj'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (widget.isLoadingCats)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (!hasCats)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(14)),
                  child: const Text(
                    'Nemaš nijednu mačku još. Klikni "Dodaj" da dodaš prvu.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final cat = widget.cats[index];
                      final selected = cat.id == widget.selectedCatId;
                      final avatarPath = avatarPaths[cat.id];
                      return GestureDetector(
                        onTap: () => widget.onSelectCat(cat.id),
                        onLongPress: () => showManageCatDialog(cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 84,
                          decoration: BoxDecoration(
                            color: selected ? Colors.lightBlue : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: selected ? Colors.lightBlue : Colors.lightBlue.shade100, width: 2),
                            boxShadow: selected
                                ? [BoxShadow(color: Colors.lightBlue.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              avatarPath != null
                                  ? CircleAvatar(
                                      radius: 16,
                                      backgroundColor: selected ? Colors.white : Colors.lightBlue.shade50,
                                      backgroundImage: FileImage(File(avatarPath)),
                                    )
                                  : const Text('🐈', style: TextStyle(fontSize: 26)),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  cat.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (hasCats) ...[
                const SizedBox(height: 6),
                const Text(
                  'Drži prst na mački za uređivanje ili brisanje',
                  style: TextStyle(color: Colors.black38, fontSize: 11),
                ),
              ],

              const SizedBox(height: 28),
              const Text('Količina obroka', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [50, 100, 150].map((grams) {
                  final selected = selectedPortion == grams;
                  return GestureDetector(
                    onTap: () => setState(() => selectedPortion = grams),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? Colors.lightBlue : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? Colors.lightBlue : Colors.lightBlue.shade100, width: 2),
                      ),
                      child: Text('$grams g',
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (isFeeding || !hasCats) ? null : feedCat,
                child: isFeeding
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('NAHRANI ODMAH 🐾'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ================= ANIMIRANA MAČKA =================
class CatMoodWidget extends StatefulWidget {
  final int feedTrigger;
  const CatMoodWidget({super.key, required this.feedTrigger});

  @override
  State<CatMoodWidget> createState() => _CatMoodWidgetState();
}


class _CatMoodWidgetState extends State<CatMoodWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _showHappy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant CatMoodWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedTrigger != oldWidget.feedTrigger) {
      _playHappyAnimation();
    }
  }

  void _playHappyAnimation() {
    setState(() => _showHappy = true);
    _controller.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showHappy = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _showHappy
                        ? [Colors.lightBlue.shade300, Colors.lightBlue.shade100]
                        : [Colors.lightBlue.shade100, Colors.lightBlue.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: Colors.lightBlue.withOpacity(0.2), blurRadius: 24, spreadRadius: 2)],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Text(
                      _showHappy ? '😻' : '🐱',
                      key: ValueKey(_showHappy),
                      style: const TextStyle(fontSize: 86),
                    ),
                  ),
                ),
              ),
              if (_showHappy)
                ...List.generate(3, (i) {
                  final interval = Interval((i * 0.15).clamp(0.0, 1.0), (0.75 + i * 0.1).clamp(0.0, 1.0), curve: Curves.easeOut);
                  final anim = CurvedAnimation(parent: _controller, curve: interval);
                  return AnimatedBuilder(
                    animation: anim,
                    builder: (context, _) {
                      final t = anim.value;
                      return Positioned(
                        bottom: 120 + 70 * t,
                        left: 85 + (i - 1) * 34,
                        child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Text('❤️', style: TextStyle(fontSize: 18 - i.toDouble())),
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
