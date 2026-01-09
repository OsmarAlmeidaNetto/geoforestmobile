import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';

class _ImagePayload {
  final String pathOriginal;
  final List<String> linhasMarcaDagua;
  final String nomeArquivoFinal;
  _ImagePayload({
    required this.pathOriginal, 
    required this.linhasMarcaDagua, 
    required this.nomeArquivoFinal
  });
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

      // O 'compute' executa o processamento pesado em uma Isolate separada
      final Uint8List? bytesFinais = await compute(_processarImagemNoFundo, payload);

      if (bytesFinais != null) {
        // O salvamento na galeria DEVE ser feito na thread principal (fora do compute)
        await Gal.putImageBytes(bytesFinais, name: nomeArquivoFinal);
        debugPrint("Foto processada e salva com sucesso: $nomeArquivoFinal");
        return pathOriginal;
      }
      return "";
    } catch (e) {
      debugPrint("ERRO CRÍTICO NO PROCESSAMENTO DE IMAGEM: $e");
      return "";
    }
  }
}

// FUNÇÃO TOP-LEVEL (Fora da classe) para performance máxima do Isolate
Uint8List? _processarImagemNoFundo(_ImagePayload payload) {
  try {
    final File file = File(payload.pathOriginal);
    if (!file.existsSync()) return null;
    
    final Uint8List inputBytes = file.readAsBytesSync();
    
    // Decodifica a imagem
    img.Image? image = img.decodeImage(inputBytes);
    if (image == null) return null;

    // Redimensionamento agressivo para preservar RAM (800px é o ponto ideal)
    if (image.width > 800 || image.height > 800) {
      image = img.copyResize(image, width: 800);
    }

    // Configuração da marca d'água
    final int alturaLinha = 25; 
    final int alturaFaixa = (payload.linhasMarcaDagua.length * alturaLinha) + 15;

    // Desenha a faixa de fundo (Preto sólido gasta menos processamento que transparente)
    img.fillRect(
      image, 
      x1: 0, 
      y1: image.height - alturaFaixa, 
      x2: image.width, 
      y2: image.height, 
      color: img.ColorRgb8(0, 0, 0)
    );

    // Escreve as linhas de texto
    for (int i = 0; i < payload.linhasMarcaDagua.length; i++) {
      int yPos = (image.height - alturaFaixa) + (i * alturaLinha) + 5;
      img.drawString(
        image, 
        payload.linhasMarcaDagua[i], 
        font: img.arial14, // Fonte pequena mas legível para 800px
        x: 10, 
        y: yPos, 
        color: img.ColorRgb8(255, 255, 255)
      );
    }

    // Codifica para JPG com qualidade moderada
    final Uint8List output = Uint8List.fromList(img.encodeJpg(image, quality: 60));
    
    // Limpeza manual para ajudar o Garbage Collector
    image = null; 
    
    return output;
  } catch (e) {
    return null;
  }
}