import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../models/game_models.dart';

const _skinNames = ['Neon', 'Inferno', 'Phantom', 'Verdant', 'Gold'];
const _skinIcons = [Icons.hexagon_outlined, Icons.local_fire_department, Icons.blur_on, Icons.electric_bolt, Icons.star];
const _skinPrices = [0, 100, 150, 200, 500];

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary), onPressed: () => Navigator.pop(context)),
        title: const Text('SHOP', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: 4)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.coinColor.withOpacity(0.3))),
            child: Row(children: [
              const Text('🪙', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('${settings.totalCoins}', style: const TextStyle(color: AppTheme.coinColor, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text('SKINS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w700)),
        ),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9),
          itemCount: SkinType.values.length,
          itemBuilder: (context, i) {
            final skin = SkinType.values[i];
            final color = skinColor(skin);
            final unlocked = settings.unlockedSkins.contains(i);
            final selected = settings.selectedSkinIndex == i;
            final price = _skinPrices[i];

            return GestureDetector(
              onTap: () {
                if (unlocked) {
                  settings.selectSkin(i);
                } else if (settings.spendCoins(price)) {
                  settings.unlockSkin(i);
                  settings.selectSkin(i);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${_skinNames[i]} unlocked!', style: const TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Not enough coins!', style: TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.danger,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : AppTheme.cardBorder,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 16, spreadRadius: 2)] : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.12),
                      border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                    ),
                    child: Icon(_skinIcons[i], color: color, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(_skinNames[i].toUpperCase(), style: TextStyle(color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text('EQUIPPED', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    )
                  else if (unlocked)
                    const Text('UNLOCKED', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, letterSpacing: 1))
                  else
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('🪙', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('$price', style: const TextStyle(color: AppTheme.coinColor, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                ]),
              ),
            );
          },
        )),

        // Remove Ads IAP placeholder
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.cardBorder)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.block, color: AppTheme.accent, size: 24)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('REMOVE ADS', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                Text('One-time purchase — play ad-free forever', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(12)),
                child: const Text('\$1.99', style: TextStyle(color: AppTheme.bg, fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
