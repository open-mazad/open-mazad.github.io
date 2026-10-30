part of '../main.dart';

// ======================= 4. بطاقة المشاركة ورمز QR =======================

void showShareQrDialog(BuildContext context, Item item) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.qr_code_2, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('بطاقة مشاركة المزاد', 'Auction Share Card'))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tr("السعر الحالي:", "Current Bid:")} ${formatPrice(item.currentPrice)}',
                  style: TextStyle(
                      color: Colors.indigo.shade800,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // رسم رمز QR مخصص للمزاد
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: CustomPaint(
                    size: const Size(140, 140),
                    painter: _QrCodePainter(seed: item.id.hashCode),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'muzaida://auction/${item.id}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.black54),
                ),
                if (item.isPrivate) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🔒 PIN: ${item.pinCode}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    final shareText =
                        '🔨 مزاد على تطبيق مزايدة (muzaida): ${item.title}\n💰 السعر الحالي: ${formatPrice(item.currentPrice)}\n📍 الموقع: ${item.location}\n🔗 الرابط: https://muzaida.app/item/${item.id}${item.isPrivate ? "\n🔒 رمز الدخول PIN: ${item.pinCode}" : ""}';
                    Clipboard.setData(ClipboardData(text: shareText));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr(
                          'تم نسخ بطاقة المزاد ورابط المشاركة لواتساب وسناب شات ✅',
                          'Share card & link copied to clipboard ✅')),
                    ));
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(tr('مشاركة (واتساب / سناب)', 'Share Card & Link')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _QrCodePainter extends CustomPainter {
  final int seed;
  const _QrCodePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 15;
    final cell = size.width / grid;
    final paint = Paint()..color = Colors.black87;

    bool isFinder(int r, int c) {
      final topLeft = r < 4 && c < 4;
      final topRight = r < 4 && c >= grid - 4;
      final bottomLeft = r >= grid - 4 && c < 4;
      return topLeft || topRight || bottomLeft;
    }

    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        bool fill = false;
        if (isFinder(r, c)) {
          fill = (r == 0 ||
              r == 3 ||
              c == 0 ||
              c == 3 ||
              r == grid - 1 ||
              r == grid - 4 ||
              c == grid - 1 ||
              c == grid - 4 ||
              (r >= 1 && r <= 2 && c >= 1 && c <= 2));
        } else {
          final hash = ((r * 31 + c * 17 + seed) & 0xFF);
          fill = hash % 2 == 0;
        }
        if (fill) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell - 0.5, cell - 0.5),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

