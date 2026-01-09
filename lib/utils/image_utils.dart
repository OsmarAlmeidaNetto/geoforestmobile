import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';

class _ImagePayload {
  final String pathOriginal;
  final List<String> linhasMarcaDagua;
  final String nomeArquivoFinal;
  _ImagePayload({required this.pathOriginal, required this.linhasMarcaDagua, required this.nomeArquivoFinal});
}

class ImageUtils {
  static Future<String> processarESalvarFoto({
    required String pathOriginal,
    required List<String> linhasMarcaDagua,
    required String nomeArquivoFinal,
  }) async {
    try {
      final payload = _ImagePayload(
        pathOriginal: pathOriginal,
        linhasMarcaDagua: linhasMarcaDagua,
        nomeArquivoFinal: nomeArquivoFinal,
      );

      // Usamos compute para não travar a UI
      final Uint8List? bytesFinais = await compute(_processarImagemNoFundo, payload);

      if (bytesFinais != null) {
        await Gal.putImageBytes(bytesFinais, name: nomeArquivoFinal);
        return pathOriginal;
      }
      return "";
    } catch (e) {
      debugPrint("ERRO CRÍTICO NO PROCESSAMENTO: $e");
      return "";
    }
  }
}

// ESTA FUNÇÃO DEVE FICAR FORA DA CLASSE OU SER TOP-LEVEL PARA MELHOR PERFORMANCE
Uint8List? _processarImagemNoFundo(_ImagePayload payload) {
  try {
    final File file = File(payload.pathOriginal);
    if (!file.existsSync()) return null;
    
    final Uint8List bytes = file.readAsBytesSync();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    // Redimensiona se a imagem ainda for muito grande (Segurança Extra de RAM)
    if (image.width > 1200) {
      image = img.copyResize(image, width: 1200);
    }

    final int alturaLinha = 30;
    final int alturaFaixa = (payload.linhasMarcaDagua.length * alturaLinha) + 20;

    img.fillRect(image, 
      x1: 0, y1: image.height - alturaFaixa, 
      x2: image.width, y2: image.height, 
      color: img.ColorRgba8(0, 0, 0, 160)
    );

    for (int i = 0; i < payload.linhasMarcaDagua.length; i++) {
      int yPos = (image.height - alturaFaixa) + (i * alturaLinha) + 10;
      img.drawString(image, payload.linhasMarcaDagua[i], 
        font: img.arial24, x: 15, y: yPos, 
        color: img.ColorRgb8(255, 255, 255)
      );
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 75)); // Qualidade 75 economiza mais RAM
  } catch (e) {
    return null;
  }
}