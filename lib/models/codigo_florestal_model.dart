// lib/models/codigo_florestal_model.dart (CORRIGIDO)

class CodigoFlorestal {
  final String sigla;
  final String descricao;
  
  // As strings "cruas" do CSV
  final String _fuste;
  final String _cap;
  final String _altura;
  final String _hipsometria; // O campo que estava "sem uso"
  final String _extraDan;
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

  // --- LÓGICA DE NEGÓCIO ---

  // CAP: Se for 'N', trava o campo.
  bool get isCapBloqueado => _cap == 'N';

  // Altura: 
  // 'S' = Obrigatório. 'N' ou 'C' = Bloqueado.
  bool get isAlturaObrigatoria => _altura == 'S';
  bool get isAlturaBloqueada => _altura == 'N' || _altura == 'C';

  // Dano: Se 'S', abre o campo de dano.
  bool get requerAlturaDano => _extraDan == 'S';

  // Fuste: Se 'S', permite adicionar fuste.
  bool get permiteMultifuste => _fuste == 'S';
  
  // Dominante: Se 'N', o checkbox de dominante fica desabilitado.
  bool get permiteDominante => _dominante != 'N';

  // <<< CORREÇÃO: ADICIONADO O GETTER QUE FALTAVA >>>
  // Hipsometria: Indica se essa árvore é candidata a medição de altura para a curva.
  bool get entraNaHipsometria => _hipsometria == 'S';

  @override
  String toString() => "$sigla - $descricao";
}