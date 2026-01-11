// Arquivo: lib/models/codigo_florestal_model.dart

class CodigoFlorestal {
  final String sigla;
  final String descricao;
  
  // Strings puras do CSV
  final String _fuste;
  final String _cap;
  final String _altura;
  final String _hipsometria; 
  final String _extraDan;
  // A coluna Dominante no CSV será ignorada ou usada apenas para saber
  // se a árvore é "candidata" (ex: Morta nunca vira dominante).
  final String _dominante; 

  CodigoFlorestal({
    required this.sigla,
    required this.descricao,
    required String fuste,
    required String cap,
    required String altura,
    required String hipsometria,
    required String extraDan,
    required String dominante,
  })  : _fuste = fuste.toUpperCase().trim(),
        _cap = cap.toUpperCase().trim(),
        _altura = altura.toUpperCase().trim(),
        _hipsometria = hipsometria.toUpperCase().trim(),
        _extraDan = extraDan.toUpperCase().trim(),
        _dominante = dominante.toUpperCase().trim();

  factory CodigoFlorestal.fromCsv(List<dynamic> row) {
    // Helper para evitar erro de índice
    String getCol(int index) => (row.length > index) ? row[index].toString() : '.';

    return CodigoFlorestal(
      sigla: getCol(0),
      descricao: getCol(1),
      fuste: getCol(2),
      cap: getCol(3),
      altura: getCol(4),
      hipsometria: getCol(5),
      extraDan: getCol(6),
      dominante: getCol(7),
    );
  }

  // --- REGRAS DE NEGÓCIO (S, N, .) ---

  // CAP
  bool get capObrigatorio => _cap == 'S';
  bool get capBloqueado => _cap == 'N';

  // Altura Total
  bool get alturaObrigatoria => _altura == 'S';
  bool get alturaBloqueada => _altura == 'N';
  // O ponto (.) significa opcional, então não é nem obrigatório nem bloqueado

  // Altura do Dano (Extra Dano)
  // Se for 'S', habilita o campo e obriga preencher
  bool get requerAlturaDano => _extraDan == 'S';

  // Fuste
  bool get permiteMultifuste => _fuste != 'N'; // Se for N, bloqueia o botão "Adic Fuste"

  // Hipsometria (Para cálculos futuros)
  bool get entraNaCurva => _hipsometria == 'S';
  
  // Dominante (Candidata)
  // Árvores mortas, caídas ou falhas geralmente têm 'N' aqui no CSV.
  // Isso impede o algoritmo de elegê-las como dominante mesmo se tiverem CAP alto (erro de digitação)
  bool get podeSerDominante => _dominante != 'N';

  @override
  String toString() => "$sigla - $descricao";
}