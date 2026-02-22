import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../models/game_models.dart';

const _skinNames = ['PHANTOM', 'NOVA', 'INFERNO', 'SPECTER', 'TITAN'];
const _skinSubtitles = ['Default Craft', 'Ion Drive', 'Plasma Core', 'Ghost Class', 'Heavy Carrier'];
const _skinPrices = [0, 100, 200, 350, 600];

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('HANGAR', style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          fontSize: 18,
        )),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.coinColor.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.circle, color: AppTheme.coinColor, size: 10),
              const SizedBox(width: 6),
              Text('${settings.totalCoins}', style: const TextStyle(
                color: AppTheme.coinColor,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              )),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            'SELECT YOUR CRAFT',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.w700),
          ),
        ),

        Expanded(child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
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
                    content: Text('${_skinNames[i]} acquired!', style: const TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Insufficient credits', style: TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.danger,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? color : AppTheme.cardBorder,
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected ? [BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 0,
                  )] : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // Ship preview
                  SizedBox(
                    width: 70, height: 80,
                    child: CustomPaint(painter: _ShipCardPainter(skin, selected)),
                  ),
                  const SizedBox(height: 10),
                  Text(_skinNames[i], style: TextStyle(
                    color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  )),
                  Text(_skinSubtitles[i], style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  )),
                  const SizedBox(height: 8),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text('ACTIVE', style: TextStyle(
                        color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2,
                      )),
                    )
                  else if (unlocked)
                    const Text('UNLOCKED', style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 1.5,
                    ))
                  else
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.circle, color: AppTheme.coinColor, size: 9),
                      const SizedBox(width: 4),
                      Text('$price', style: const TextStyle(
                        color: AppTheme.coinColor, fontWeight: FontWeight.w900, fontSize: 13,
                      )),
                    ]),
                ]),
              ),
            );
          },
        )),

        // Remove ads card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.block, color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AD-FREE PILOT', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                SizedBox(height: 2),
                Text('One purchase — fly forever uninterrupted', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('\$1.99', style: TextStyle(
                  color: AppTheme.bg, fontWeight: FontWeight.w900, fontSize: 13,
                )),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ShipCardPainter extends CustomPainter {
  final SkinType skin;
  final bool selected;
  _ShipCardPainter(this.skin, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.3;
    final color = skinColor(skin);
    final paint = Paint()..style = PaintingStyle.fill;

    if (selected) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      paint.color = color.withOpacity(0.35);
      canvas.drawCircle(Offset(cx, cy), r + 8, paint);
      paint.maskFilter = null;
    }

    final bodyPath = Path();
    bodyPath.moveTo(cx, cy - r * 1.1);
    bodyPath.cubicTo(cx + r * 0.75, cy - r * 0.15, cx + r * 0.95, cy + r * 0.3, cx + r * 0.55, cy + r * 0.8);
    bodyPath.lineTo(cx + r * 0.55, cy + r * 1.0);
    bodyPath.lineTo(cx + r * 0.3, cy + r * 0.8);
    bodyPath.lineTo(cx, cy + r * 0.65);
    bodyPath.lineTo(cx - r * 0.3, cy + r * 0.8);
    bodyPath.lineTo(cx - r * 0.55, cy + r * 1.0);
    bodyPath.lineTo(cx - r * 0.55, cy + r * 0.8);
    bodyPath.cubicTo(cx - r * 0.95, cy + r * 0.3, cx - r * 0.75, cy - r * 0.15, cx, cy - r * 1.1);
    bodyPath.close();

    paint.shader = LinearGradient(
      colors: [Colors.white.withOpacity(0.85), color, color.withOpacity(0.4)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(cx - r, cy - r * 1.2, r * 2, r * 2.4));
    canvas.drawPath(bodyPath, paint);
    paint.shader = null;

    // Cockpit
    paint.color = AppTheme.accentAlt.withOpacity(0.7);
    final cp = Path();
    cp.moveTo(cx, cy - r * 0.65);
    cp.cubicTo(cx + r * 0.28, cy - r * 0.25, cx + r * 0.28, cy + r * 0.1, cx, cy + r * 0.2);
    cp.cubicTo(cx - r * 0.28, cy + r * 0.1, cx - r * 0.28, cy - r * 0.25, cx, cy - r * 0.65);
    canvas.drawPath(cp, paint);
  }

  @override
  bool shouldRepaint(_ShipCardPainter old) => false;
}
