import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:geoforestv1/data/datasources/local/database_constants.dart';
import 'package:flutter/foundation.dart'; // Para o debugPrint

enum Codigo {
  // --- Básicos (Já existiam) ---
  Normal, 
  Falha, 
  BifurcadaAcima, // A
  BifurcadaAbaixo, 
  Multipla, 
  Quebrada, 
  Caida,      // No CSV novo: CA (Caida ou Deitada)
  Dominada, 
  Geada, 
  Fogo,
  PragasOuDoencas, 
  AtaqueMacaco, // Genérico
  VespaMadeira, 
  MortaOuSeca, 
  PonteiraSeca,
  Rebrota, 
  AtaqueFormiga, 
  Torta, 
  FoxTail, 
  Inclinada, 
  DeitadaVento, // No CSV novo: W
  FeridaBase, 
  CaidaRaizVento, // No CSV novo: CR
  Resinado, 
  Outro,
  // --- NOVOS (Adicionados baseados nas imagens) ---
  


  // Específicos de Dominância/Desbaste
  DominanteAssmann, // H
  MarcadaDesbaste,  // DS

  // Danos Específicos
  AtaqueMacacoJanela, // J
  AtaqueMacacoAnel,   // K
  MortoPorMacaco,     // N (Cuidado: N no CSV também é Normal em alguns, a lógica tratará)

  // Inventário Contínuo / Qualidade
  Ingresso, // I
  
  // Cobertura de Solo / Competição
  GramineaExotica, // GraE
  GramineaNativa,  // GraN
  SoloExposto,     // SolE
  Arbusto,         // Arb
  
  // Peso e Defeitos de Tora
  Peso2,           // P2
  DefeitoSup,      // D3S (Terço Superior)
  DefeitoMed,      // D3M (Terço Médio)
  DefeitoInf,      // D3I (Terço Inferior)
  
  // Controle Operacional
  SubAmostra,       // Sub
  SubstEtiqueta,    // SuE
  CodigoGPS,        // GPS
  AmostraVazia      // Ava
}

enum Codigo2 {
  Bifurcada,   
  Quebrada,        // No CSV novo: CA (Caida ou Deitada)
  Geada, 
  Fogo,
  PragasOuDoencas, 
  AtaqueMacaco, // Genérico
  VespaMadeira,   
  PonteiraSeca,
  Rebrota, 
  AtaqueFormiga, 
  Torta, 
  FoxTail, 
  Inclinada, 
  DeitadaVento, // No CSV novo: W
  FeridaBase, 
  CaidaRaizVento, // No CSV novo: CR
  Resinado, 
  Outro,

  // --- NOVOS (Adicionados baseados nas imagens) ---
  
  // Variações de Bifurcação
  BifurcadaAcima, // A
  BifurcadaAbaixo, // B ou BF

  // Específicos de Dominância/Desbaste
  DominanteAssmann, // H
  MarcadaDesbaste,  // DS

  // Danos Específicos
  AtaqueMacacoJanela, // J
  AtaqueMacacoAnel,   // K
  MortoPorMacaco,     // N (Cuidado: N no CSV também é Normal em alguns, a lógica tratará)

  // Inventário Contínuo / Qualidade
  Ingresso, // I
  
  // Cobertura de Solo / Competição
  GramineaExotica, // GraE
  GramineaNativa,  // GraN
  SoloExposto,     // SolE
  Arbusto,         // Arb
  
  // Peso e Defeitos de Tora
  Peso2,           // P2
  DefeitoSup,      // D3S (Terço Superior)
  DefeitoMed,      // D3M (Terço Médio)
  DefeitoInf,      // D3I (Terço Inferior)
  
  // Controle Operacional
  SubAmostra,       // Sub
  SubstEtiqueta,    // SuE
  CodigoGPS,        // GPS
  AmostraVazia      // Ava
}

class Arvore {
  int? id;
  final double cap;
  final double? altura;
  final double? alturaDano;
  final int linha;
  final int posicaoNaLinha;
  final bool fimDeLinha;
  bool dominante;
  final Codigo codigo;
  final Codigo2? codigo2;
  final String? codigo3;
  final String? especie;
  final int? tora;
  final double? capAuditoria;
  final double? alturaAuditoria;
  double? volume;
  final List<String> photoPaths; // <--- Lista de caminhos das fotos
  final DateTime? lastModified;

  Arvore({
    this.id, required this.cap, this.altura, this.alturaDano, required this.linha,
    required this.posicaoNaLinha, this.fimDeLinha = false, this.dominante = false,
    required this.codigo, this.codigo2, this.codigo3, this.especie, this.tora,
    this.capAuditoria, this.alturaAuditoria, this.volume, 
    this.photoPaths = const [], 
    this.lastModified,
  });

  Arvore copyWith({
    int? id, double? cap, double? altura, double? alturaDano, int? linha,
    int? posicaoNaLinha, bool? fimDeLinha, bool? dominante, Codigo? codigo,
    Codigo2? codigo2, String? codigo3, String? especie, int? tora, double? capAuditoria,
    double? alturaAuditoria, double? volume, List<String>? photoPaths,
    DateTime? lastModified,
  }) {
    return Arvore(
      id: id ?? this.id, cap: cap ?? this.cap, altura: altura ?? this.altura,
      alturaDano: alturaDano ?? this.alturaDano, linha: linha ?? this.linha,
      posicaoNaLinha: posicaoNaLinha ?? this.posicaoNaLinha,
      fimDeLinha: fimDeLinha ?? this.fimDeLinha, dominante: dominante ?? this.dominante,
      codigo: codigo ?? this.codigo, codigo2: codigo2 ?? this.codigo2,
      codigo3: codigo3 ?? this.codigo3, especie: especie ?? this.especie, tora: tora ?? this.tora,
      capAuditoria: capAuditoria ?? this.capAuditoria,
      alturaAuditoria: alturaAuditoria ?? this.alturaAuditoria,
      volume: volume ?? this.volume, 
      photoPaths: photoPaths ?? this.photoPaths,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbArvores.id: id,
      DbArvores.cap: cap,
      DbArvores.altura: altura,
      DbArvores.alturaDano: alturaDano,
      DbArvores.linha: linha,
      DbArvores.posicaoNaLinha: posicaoNaLinha,
      DbArvores.fimDeLinha: fimDeLinha ? 1 : 0,
      DbArvores.dominante: dominante ? 1 : 0,
      DbArvores.codigo: codigo.name,
      DbArvores.codigo2: codigo2?.name,
      DbArvores.codigo3: codigo3,
      'especie': especie,
      DbArvores.tora: tora,
      DbArvores.capAuditoria: capAuditoria,
      DbArvores.alturaAuditoria: alturaAuditoria,
      // Salva como String JSON no SQLite
      DbArvores.photoPaths: jsonEncode(photoPaths), 
      DbArvores.lastModified: lastModified?.toIso8601String(),
    };
  }

  factory Arvore.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    // Lógica robusta para ler photoPaths (SQLite String ou Firebase List)
    List<String> paths = [];
    if (map[DbArvores.photoPaths] != null) {
      var rawPaths = map[DbArvores.photoPaths];
      if (rawPaths is String && rawPaths.isNotEmpty) {
        try {
          var decoded = jsonDecode(rawPaths);
          if (decoded is List) paths = List<String>.from(decoded);
        } catch (e) {
          debugPrint("Erro ao decodificar photoPaths: $e");
        }
      } else if (rawPaths is List) {
        paths = List<String>.from(rawPaths);
      }
    }

    return Arvore(
      id: map[DbArvores.id],
      cap: (map[DbArvores.cap] as num?)?.toDouble() ?? 0.0,
      altura: (map[DbArvores.altura] as num?)?.toDouble(),
      alturaDano: (map[DbArvores.alturaDano] as num?)?.toDouble(),
      linha: map[DbArvores.linha] ?? 0,
      posicaoNaLinha: map[DbArvores.posicaoNaLinha] ?? 0,
      fimDeLinha: map[DbArvores.fimDeLinha] == 1,
      dominante: map[DbArvores.dominante] == 1,
      codigo: Codigo.values.firstWhere((e) => e.name == map[DbArvores.codigo], orElse: () => Codigo.Normal),
      codigo2: map[DbArvores.codigo2] != null
          ? Codigo2.values.firstWhereOrNull((e) => e.name.toLowerCase() == map[DbArvores.codigo2].toString().toLowerCase())
          : null,
      codigo3: map[DbArvores.codigo3],
      especie: map['especie'],
      tora: map[DbArvores.tora],
      capAuditoria: (map[DbArvores.capAuditoria] as num?)?.toDouble(),
      alturaAuditoria: (map[DbArvores.alturaAuditoria] as num?)?.toDouble(),
      photoPaths: paths,
      lastModified: parseDate(map[DbArvores.lastModified]),
    );
  }
}