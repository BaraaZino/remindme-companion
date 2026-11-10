import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme_companion/animal_catalog.dart';
import 'package:remindme_companion/pixel_cat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Render every animal and four walk poses at a consistent scale',
      () async {
    await (FontLoader('Nunito')
          ..addFont(rootBundle.load('assets/fonts/Nunito.ttf')))
        .load();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFF8F7F2), BlendMode.src);
    for (var row = 0; row < animalDesigns.length; row++) {
      final animal = animalDesigns[row];
      final text = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
              text: animal.label,
              style: const TextStyle(
                  color: Color(0xFF293E34),
                  fontSize: 18,
                  fontFamily: 'Nunito')))
        ..layout();
      text.paint(canvas, Offset(16, row * 140 + 52));
      for (var frame = 0; frame < 4; frame++) {
        canvas.save();
        canvas.translate(125 + frame * 120.0, row * 140.0 + 8);
        AnimalPainter(
                phase: frame / 24,
                walking: true,
                talking: false,
                animal: animal.id,
                color: animal.color,
                accent: animal.accent,
                faceRight: true)
            .paint(canvas, const Size(108, 120));
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(620, animalDesigns.length * 140);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../.tools/companions-animal-study.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();

    final galleryRecorder = ui.PictureRecorder();
    final gallery = Canvas(galleryRecorder);
    gallery.drawColor(const Color(0xFFF8F7F2), BlendMode.src);
    for (var i = 0; i < animalDesigns.length; i++) {
      final animal = animalDesigns[i];
      gallery.save();
      gallery.translate((i % 5) * 124.0 + 8, (i ~/ 5) * 156.0 + 8);
      AnimalPainter(
              phase: 0,
              walking: false,
              talking: false,
              animal: animal.id,
              color: animal.color,
              accent: animal.accent,
              faceRight: true)
          .paint(gallery, const Size(108, 120));
      final label = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
              text: animal.label,
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  color: Color(0xFF293E34))))
        ..layout();
      label.paint(gallery, Offset((108 - label.width) / 2, 122));
      gallery.restore();
    }
    final galleryPicture = galleryRecorder.endRecording();
    final galleryImage = await galleryPicture.toImage(
        620, ((animalDesigns.length + 4) ~/ 5) * 156);
    final galleryBytes =
        await galleryImage.toByteData(format: ui.ImageByteFormat.png);
    await File('../.tools/companions-gallery.png')
        .writeAsBytes(galleryBytes!.buffer.asUint8List());
    galleryImage.dispose();
    galleryPicture.dispose();
  });
}
