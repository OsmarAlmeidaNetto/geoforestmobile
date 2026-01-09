import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';

class ImageUtils {
  static Future<void> processarESalvarFoto({
    required String pathOriginal,
    required List<String> linhasMarcaDagua,
    required String nomeArquivoFinal,
  }) async {
    try {
      // PASSO 1: Compressão Nativa (Roda fora do Dart, não gasta RAM do app)
      // Reduzimos para 800px que é o tamanho ideal para ver detalhes e ler o texto
      final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        pathOriginal,
        minWidth: 800,
        minHeight: 800,
        quality: 60,
      );

      if (compressedBytes == null) return;

      // PASSO 2: Desenhar marca d'água usando um Isolate (compute)
      // O 'compute' cria uma thread separada só para essa tarefa, evitando o crash
      final Uint8List finalBytes = await compute(_desenharMarcaDaguaIsolate, {
        'bytes': compressedBytes,
        'linhas': linhasMarcaDagua,
      });

      // PASSO 3: Salva na galeria
      await Gal.putImageBytes(finalBytes, name: nomeArquivoFinal);

      // Limpeza: Deleta o arquivo original temporário
      final file = File(pathOriginal);
      if (await file.exists()) await file.delete();
      
    } catch (e) {
      debugPrint("ERRO NA IMAGEM: $e");
    }
  }
}

// Função que roda em Isolate (Sala separada da memória)
Uint8List _desenharMarcaDaguaIsolate(Map<String, dynamic> data) {
  final Uint8List bytes = data['bytes'];
  final List<String> linhas = data['linhas'];

  // Como a imagem já foi reduzida pelo compressor nativo, o decode aqui é levíssimo
  final image = img.decodeJpg(bytes);
  if (image == null) return bytes;

  const int alturaLinha = 25;
  final int alturaTarja = (linhas.length * alturaLinha) + 15;

  // Desenha tarja preta sólida (mais leve que transparente)
  img.fillRect(
    image,
    x1: 0, y1: image.height - alturaTarja,
    x2: image.width, y2: image.height,
    color: img.ColorRgb8(0, 0, 0),
  );

  // Escreve o texto
  for (int i = 0; i < linhas.length; i++) {
    img.drawString(
      image,
      linhas[i],
      font: img.arial14,
      x: 15,
      y: (image.height - alturaTarja) + (i * alturaLinha) + 8,
      color: img.ColorRgb8(255, 255, 255),
    );
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 70));
}