import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Lista rasa — dopuni/izmijeni po potrebi.
const List<String> kPopularCatBreeds = [
  'Abyssinian',
  'American Shorthair',
  'Bengal',
  'British Shorthair',
  'Devon Rex',
  'Exotic',
  'Maine Coon',
  'Persian',
  'Ragdoll',
  'Russian Blue',
  'Scottish Fold',
  'Siamese',
  'Sphynx',
  'Domaća mačka',
];

class BreedSelectScreen extends StatefulWidget {
  final String? initialBreed;

  const BreedSelectScreen({super.key, this.initialBreed});

  @override
  State<BreedSelectScreen> createState() => _BreedSelectScreenState();
}

class _BreedSelectScreenState extends State<BreedSelectScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.isEmpty) return kPopularCatBreeds;
    return kPopularCatBreeds.where((b) => b.toLowerCase().contains(_query.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breed'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search breed',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black87)),
                ),
              ),
              const SizedBox(height: 18),
              if (_query.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Popular breeds', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black54)),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final breed = _filtered[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.tint50,
                        child: Text(breed.isNotEmpty ? breed[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(breed, style: const TextStyle(fontSize: 15)),
                      trailing: breed == widget.initialBreed ? const Icon(Icons.check, color: Colors.green, size: 20) : null,
                      onTap: () => Navigator.pop(context, breed),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
