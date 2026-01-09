import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // OBRIGATÓRIO PARA O COMPUTE
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';

/// Classe auxiliar interna para transportar dados para a Isolate
class _ImagePayload {
  final String pathOriginal;
  final List<String> linhasMarcaDagua;
  final String nomeArquivoFinal;

  _ImagePayload({
    required this.pathOriginal,
    required this.linhasMarcaDagua,
    required this.nomeArquivoFinal,
  });
}

class ImageUtils {
  /// Método principal que você chama na sua UI.
  /// Ele não trava a tela pois usa o 'compute'.
  static Future<String> processarESalvarFoto({
    required String pathOriginal,
    required List<String> linhasMarcaDagua,
    required String nomeArquivoFinal,
  }) async {
    final payload = _ImagePayload(
      pathOriginal: pathOriginal,
      linhasMarcaDagua: linhasMarcaDagua,
      nomeArquivoFinal: nomeArquivoFinal,
    );

    // O 'compute' envia o trabalho pesado para o "fundo" do processador
    final Uint8List? bytesFinais = await compute(_processarImagemNoFundo, payload);

    if (bytesFinais != null) {
      // O salvamento na galeria deve ocorrer na Main Thread (onde o Gal funciona)
      await Gal.putImageBytes(bytesFinais, name: nomeArquivoFinal);
    } else {
      throw Exception("Falha ao processar imagem.");
    }

    return pathOriginal;
  }

  /// ESTA FUNÇÃO RODA EM SEGUNDO PLANO (ISOLATE)
  /// Não tem acesso à UI, apenas processamento matemático.
  static Uint8List? _processarImagemNoFundo(_ImagePayload payload) {
    // 1. Lê o arquivo de forma síncrona dentro da isolate
    final File file = File(payload.pathOriginal);
    final Uint8List bytes = file.readAsBytesSync();

    // 2. Decodifica a imagem (AQUI É ONDE O APP COSTUMA TRAVAR)
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    final int alturaLinha = 28;
    final int alturaFaixa = (payload.linhasMarcaDagua.length * alturaLinha) + 15;

    // 3. Desenha a faixa preta (Marca D'água)
    img.fillRect(
      image,
      x1: 0,
      y1: image.height - alturaFaixa,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(0, 0, 0, 128),
    );

    // 4. Escreve cada linha de texto
    for (int i = 0; i < payload.linhasMarcaDagua.length; i++) {
      int yPos = (image.height - alturaFaixa) + (i * alturaLinha) + 10;
      img.drawString(
        image,
        payload.linhasMarcaDagua[i],
        font: img.arial24,
        x: 10,
        y: yPos,
        color: img.ColorRgb8(255, 255, 255),
      );
    }

    // 5. Codifica para JPG (Outra tarefa pesada)
    // Reduzimos a qualidade para 80 para economizar MUITA memória e espaço
    return Uint8List.fromList(img.encodeJpg(image, quality: 80));
  }
}