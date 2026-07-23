import 'package:flutter/material.dart';
import '../models/cat.dart';
import 'schedules_and_logs_screen.dart';

class ServicesScreen extends StatelessWidget {
  final String baseUrl;
  final List<Cat> cats;
  const ServicesScreen({super.key, required this.baseUrl, required this.cats});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servisi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _ServiceCard(
              icon: Icons.event_note_rounded,
              color: Colors.lightBlue,
              title: 'Raspored hranjenja i evidencija',
              subtitle: 'Podesi automatsko hranjenje i pregledaj historiju',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SchedulesAndLogsScreen(baseUrl: baseUrl, cats: cats)),
              ),
            ),
            const SizedBox(height: 14),
            _ServiceCard(
              icon: Icons.storefront_rounded,
              color: Colors.deepOrange,
              title: 'Prodavnica',
              subtitle: 'Hrana, dodaci i oprema — uskoro',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uskoro dostupno.')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ServiceCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
