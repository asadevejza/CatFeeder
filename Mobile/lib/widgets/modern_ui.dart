import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  const ModernCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = AppColors.card, this.radius = 22, this.onTap});
  @override Widget build(BuildContext context) {
    final box = Container(padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), border: Border.all(color: AppColors.cardBorder), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 20, offset: const Offset(0,8))]), child: child);
    return onTap == null ? box : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: box);
  }
}

class SectionTitle extends StatelessWidget {
  final String title; final String? action; final VoidCallback? onAction;
  const SectionTitle({super.key, required this.title, this.action, this.onAction});
  @override Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textDark, letterSpacing: -.3))), if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primarySoft)))]);
}

class StatusPill extends StatelessWidget {
  final String text; final bool positive;
  const StatusPill({super.key, required this.text, this.positive = true});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: positive ? AppColors.mint : AppColors.blush, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: positive ? AppColors.mintStrong : AppColors.danger, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: positive ? const Color(0xFF277A5C) : AppColors.danger))]));
}

class MetricTile extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color tint;
  const MetricTile({super.key, required this.icon, required this.label, required this.value, required this.tint});
  @override Widget build(BuildContext context) => Expanded(child: ModernCard(padding: const EdgeInsets.all(14), radius: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 34,height:34,decoration:BoxDecoration(color:tint,borderRadius:BorderRadius.circular(11)),child:Icon(icon,size:18,color:AppColors.primary)), const SizedBox(height:10), Text(label,style:const TextStyle(fontSize:10.5,color:AppColors.textMuted,fontWeight:FontWeight.w700)), const SizedBox(height:3), Text(value,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:AppColors.textDark))])));
}

class CatAvatar extends StatelessWidget {
  final Uint8List? bytes; final double radius; final String fallback;
  const CatAvatar({super.key, this.bytes, this.radius=34, this.fallback='🐈'});
  @override Widget build(BuildContext context) => CircleAvatar(radius:radius, backgroundColor:AppColors.lavender, backgroundImage:bytes != null ? MemoryImage(bytes!) : null, child:bytes==null?Text(fallback,style:TextStyle(fontSize:radius*.9)):null);
}

class MiniProgress extends StatelessWidget {
  final double value; final Color color;
  const MiniProgress({super.key, required this.value, required this.color});
  @override Widget build(BuildContext context) => ClipRRect(borderRadius:BorderRadius.circular(10),child:LinearProgressIndicator(minHeight:7,value:(value/100).clamp(0,1),backgroundColor:AppColors.background,valueColor:AlwaysStoppedAnimation(color)));
}
