import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() async {
  stdout.writeln('🎨 Генерация иконки приложения MediAI...');

  // Создаем изображение 1024x1024
  final icon = img.Image(width: 1024, height: 1024);

  // Заполняем градиентом от #1F7A71 до #2A9D8F
  for (int y = 0; y < 1024; y++) {
    for (int x = 0; x < 1024; x++) {
      // Градиент от верхнего левого к нижнему правому
      final t = (x + y) / (1024 + 1024);
      
      // Primary: #1F7A71 (RGB: 31, 122, 113)
      // Primary Glow: #2A9D8F (RGB: 42, 157, 143)
      final r = (31 + (42 - 31) * t).round();
      final g = (122 + (157 - 122) * t).round();
      final b = (113 + (143 - 113) * t).round();

      // Создаем маску для закругленного квадрата (squircle)
      final centerX = 512.0;
      final centerY = 512.0;
      final radius = 462.0; // Размер области с учетом закругления
      final cornerRadius = 226.0; // ~22% от 1024

      // Проверяем, находится ли точка внутри squircle
      final dx = (x - centerX).abs();
      final dy = (y - centerY).abs();

      bool isInside = false;
      if (dx <= radius - cornerRadius && dy <= radius - cornerRadius) {
        // Внутри прямоугольной части
        isInside = true;
      } else if (dx > radius - cornerRadius && dy > radius - cornerRadius) {
        // В области закругления
        final cornerCenterX = radius - cornerRadius;
        final cornerCenterY = radius - cornerRadius;
        final distToCorner = math.sqrt(
          math.pow(dx - cornerCenterX, 2) + math.pow(dy - cornerCenterY, 2),
        );
        isInside = distToCorner <= cornerRadius;
      } else if (dx <= radius && dy <= radius) {
        isInside = true;
      }

      if (isInside) {
        icon.setPixelRgba(x, y, r, g, b, 255);
      } else {
        icon.setPixelRgba(x, y, 0, 0, 0, 0); // Прозрачный
      }
    }
  }

  // Рисуем brain иконку (упрощенная версия)
  // Создаем белый brain силуэт
  _drawBrainIcon(icon);

  // Сохраняем PNG
  final directory = Directory('assets/images');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  final pngBytes = img.encodePng(icon);
  final file = File('assets/images/app_icon.png');
  await file.writeAsBytes(pngBytes);

  stdout.writeln('✅ Иконка создана: assets/images/app_icon.png');
  stdout.writeln('📦 Запускаю flutter_launcher_icons...');
}

void _drawBrainIcon(img.Image image) {
  // Упрощенная brain иконка - два больших круга (полушария)
  const centerX = 512;
  const centerY = 512;

  // Левое полушарие
  _drawCircle(
    image,
    centerX - 80,
    centerY,
    140,
    255,
    255,
    255,
    255,
  );

  // Правое полушарие
  _drawCircle(
    image,
    centerX + 80,
    centerY,
    140,
    255,
    255,
    255,
    255,
  );

  // Детали мозга (извилины) - несколько меньших кругов
  final details = <List<int>>[
    [centerX - 120, centerY - 60, 40],
    [centerX - 60, centerY - 80, 35],
    [centerX, centerY - 70, 30],
    [centerX + 60, centerY - 80, 35],
    [centerX + 120, centerY - 60, 40],
    [centerX - 100, centerY + 40, 35],
    [centerX, centerY + 50, 30],
    [centerX + 100, centerY + 40, 35],
  ];

  for (final detail in details) {
    _drawCircle(
      image,
      detail[0],
      detail[1],
      detail[2],
      255,
      255,
      255,
      255,
    );
  }

  // Центральное соединение
  _drawCircle(image, centerX, centerY - 20, 30, 255, 255, 255, 255);
  _drawCircle(image, centerX, centerY + 20, 25, 255, 255, 255, 255);
}

void _drawCircle(
  img.Image image,
  int cx,
  int cy,
  int radius,
  int r,
  int g,
  int b,
  int a,
) {
  for (int y = cy - radius; y <= cy + radius; y++) {
    for (int x = cx - radius; x <= cx + radius; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        final distance = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
        if (distance <= radius) {
          // Сглаживание краев
          final alpha = distance >= radius - 2
              ? ((radius - distance) / 2 * a).round()
              : a;
          image.setPixelRgba(x, y, r, g, b, alpha);
        }
      }
    }
  }
}
