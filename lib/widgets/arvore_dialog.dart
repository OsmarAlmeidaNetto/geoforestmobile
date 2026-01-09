import 'package:flutter/material.dart';
import 'package:geoforestv1/models/arvore_model.dart';
import 'package:geoforestv1/models/especie_model.dart';
import 'package:geoforestv1/data/repositories/especie_repository.dart';
import 'package:geoforestv1/utils/image_utils.dart'; // Certifique-se de ter criado este arquivo
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class DialogResult {
  final Arvore arvore;
  final bool irParaProxima;
  final bool continuarNaMesmaPosicao;
  final bool atualizarEProximo;
  final bool atualizarEAnterior;

  DialogResult({
    required this.arvore,
    this.irParaProxima = false,
    this.continuarNaMesmaPosicao = false,
    this.atualizarEProximo = false,
    this.atualizarEAnterior = false,
  });
}

class ArvoreDialog extends StatefulWidget {
  final Arvore? arvoreParaEditar;
  final int linhaAtual;
  final int posicaoNaLinhaAtual;
  final bool isAdicionandoFuste;
  final bool isBio;
  
  // Informações para a Marca D'água da Foto
  final String projetoNome;
  final String fazendaNome;
  final String talhaoNome;
  final String idParcela;

  const ArvoreDialog({
    super.key,
    this.arvoreParaEditar,
    required this.linhaAtual,
    required this.posicaoNaLinhaAtual,
    this.isAdicionandoFuste = false,
    this.isBio = false,
    required this.projetoNome,
    required this.fazendaNome,
    required this.talhaoNome,
    required this.idParcela,
  });

  bool get isEditing => arvoreParaEditar != null && !isAdicionandoFuste;

  @override
  State<ArvoreDialog> createState() => _ArvoreDialogState();
}

class _ArvoreDialogState extends State<ArvoreDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final _capController = TextEditingController();
  final _alturaController = TextEditingController();
  final _linhaController = TextEditingController();
  final _posicaoController = TextEditingController();
  final _alturaDanoController = TextEditingController();
  final _especieController = TextEditingController();
  
  final _especieRepository = EspecieRepository();

  late Codigo _codigo;
  Codigo2? _codigo2;
  bool _fimDeLinha = false;
  bool _camposHabilitados = true;
  bool _isInMultiplaFlow = false;
  
  // Lista para armazenar os caminhos das fotos tiradas NESTE diálogo
  List<String> _fotosArvore = [];
  bool _processandoFoto = false;

  final _codesRequiringAlturaDano = [
    Codigo.Bifurcada, Codigo.Multipla, Codigo.Quebrada,
    Codigo.AtaqueMacaco, Codigo.Fogo, Codigo.PragasOuDoencas,
    Codigo.VespaMadeira, Codigo.MortaOuSeca, Codigo.PonteiraSeca,
    Codigo.Rebrota, Codigo.AtaqueFormiga, Codigo.Torta,
    Codigo.FoxTail, Codigo.FeridaBase, Codigo.Resinado, Codigo.Outro
  ];

  @override
  void initState() {
    super.initState();
    final arvore = widget.arvoreParaEditar;

    if (arvore != null) {
      _capController.text = (arvore.cap > 0) ? arvore.cap.toString().replaceAll('.', ',') : '';
      _alturaController.text = arvore.altura?.toString().replaceAll('.', ',') ?? '';
      _alturaDanoController.text = arvore.alturaDano?.toString().replaceAll('.', ',') ?? '';
      _especieController.text = arvore.especie ?? '';
      _codigo = arvore.codigo;
      _codigo2 = arvore.codigo2;
      _fimDeLinha = arvore.fimDeLinha;
      _linhaController.text = arvore.linha.toString();
      _posicaoController.text = arvore.posicaoNaLinha.toString();
      _fotosArvore = List.from(arvore.photoPaths); // Carrega fotos existentes
    } else {
      _codigo = Codigo.Normal;
      _linhaController.text = widget.linhaAtual.toString();
      _posicaoController.text = widget.posicaoNaLinhaAtual.toString();      
    }

    _checkMultiplaFlow();
    _atualizarEstadoCampos();
  }

  void _checkMultiplaFlow() {
    setState(() {
      _isInMultiplaFlow = _codigo == Codigo.Multipla;
    });
  }

  void _atualizarEstadoCampos() {
    setState(() {
      if (_codigo == Codigo.Falha || _codigo == Codigo.Caida) {
        _camposHabilitados = false;
        _capController.text = '0';
        _alturaController.clear();
        _alturaDanoController.clear();
        if (!widget.isEditing) _especieController.clear();
      } else {
        _camposHabilitados = true;
        if (_capController.text == '0') _capController.clear();
      }
    });
  }

  // FUNÇÃO DE CAPTURA DE FOTO COM MARCA D'ÁGUA
  // Localize a função _capturarFoto no seu arvore_dialog.dart e substitua por esta:
Future<void> _capturarFoto() async {
  final picker = ImagePicker();
  
  // 1. PRIMEIRA BARREIRA: Reduz a foto logo na captura (800 ou 1000 é o ideal)
  final XFile? photo = await picker.pickImage(
    source: ImageSource.camera, 
    imageQuality: 50, 
    maxWidth: 1000, 
    maxHeight: 1000,   
  );
  
  if (photo == null) return;

  setState(() => _processandoFoto = true);

  try {
    // 2. BUSCA DE DADOS (Garante que não enviamos strings vazias)
    final linha = _linhaController.text.isEmpty ? "N/I" : _linhaController.text;
    final pos = _posicaoController.text.isEmpty ? "N/I" : _posicaoController.text;
    final especie = _especieController.text.isEmpty ? "Não informada" : _especieController.text;

    final List<String> linhasDagua = [
      "PROJETO: ${widget.projetoNome}",
      "LOCAL: ${widget.fazendaNome} | ${widget.talhaoNome}",
      "PARCELA: ${widget.idParcela} | L:$linha | P:$pos",
      "ESPÉCIE: $especie",
      "DATA: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}"
    ];

    final nomeArquivo = "TREE_L${linha}_P${pos}_${DateTime.now().millisecondsSinceEpoch}.jpg";

    // 3. CHAMA O MOTOR NATIVO (Otimizado para não crashar)
    // Este método vai comprimir, desenhar a tarja e salvar na Galeria
    await ImageUtils.processarESalvarFoto(
      pathOriginal: photo.path,
      linhasMarcaDagua: linhasDagua,
      nomeArquivoFinal: nomeArquivo,
    );

    // 4. ATUALIZA A LISTA LOCAL
    // Mantemos o photo.path para exibição da miniatura na tela atual
    setState(() {
      _fotosArvore.add(photo.path);
    });

  } catch (e) {
    debugPrint("Erro ao processar foto da árvore: $e");
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar foto: $e"), backgroundColor: Colors.red)
      );
    }
  } finally {
    if (mounted) setState(() => _processandoFoto = false);
  }
}

  @override
  void dispose() {
    _capController.dispose();
    _alturaController.dispose();
    _linhaController.dispose();
    _posicaoController.dispose();
    _alturaDanoController.dispose();
    _especieController.dispose();
    super.dispose();
  }

  void _submit({bool proxima = false, bool mesmoFuste = false, bool atualizarEProximo = false, bool atualizarEAnterior = false}) {
    if (_formKey.currentState!.validate()) {
      if (widget.isBio && _camposHabilitados) {
        if (_especieController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Espécie é obrigatória.'), backgroundColor: Colors.red));
          return;
        }
        if (_alturaController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Altura é obrigatória.'), backgroundColor: Colors.red));
          return;
        }
      }

      final double cap = double.tryParse(_capController.text.replaceAll(',', '.')) ?? 0.0;
      final double? altura = _alturaController.text.isNotEmpty ? double.tryParse(_alturaController.text.replaceAll(',', '.')) : null;
      final double? alturaDano = _alturaDanoController.text.isNotEmpty ? double.tryParse(_alturaDanoController.text.replaceAll(',', '.')) : null;
      final int linha = int.tryParse(_linhaController.text) ?? widget.linhaAtual;
      final int posicao = int.tryParse(_posicaoController.text) ?? widget.posicaoNaLinhaAtual;

      final arvore = Arvore(
        id: widget.arvoreParaEditar?.id,
        cap: cap,
        altura: altura,
        alturaDano: alturaDano,
        especie: _especieController.text.trim(), 
        linha: linha,
        posicaoNaLinha: posicao,
        codigo: _codigo,
        codigo2: _codigo == Codigo.Normal ? null : _codigo2,
        fimDeLinha: _fimDeLinha,
        dominante: widget.arvoreParaEditar?.dominante ?? false,
        photoPaths: _fotosArvore, // <--- SALVA AS FOTOS NO OBJETO
        lastModified: DateTime.now(),
      );

      Navigator.of(context).pop(DialogResult(
        arvore: arvore,
        irParaProxima: proxima,
        continuarNaMesmaPosicao: mesmoFuste,
        atualizarEProximo: atualizarEProximo,
        atualizarEAnterior: atualizarEAnterior,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showAlturaDano = _codesRequiringAlturaDano.contains(_codigo);
    final bool isCodigoNormal = _codigo == Codigo.Normal;

    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing
                    ? 'Editar Árvore L${_linhaController.text}/P${_posicaoController.text}'
                    : 'Adicionar Árvore L${_linhaController.text}/P${_posicaoController.text}',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (widget.isBio)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("Inventário BIO (Nativa)", 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _linhaController,
                            decoration: const InputDecoration(labelText: 'Linha'),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            validator: (v) => (v == null || v.isEmpty) ? 'Inválido' : null,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: TextFormField(
                            controller: _posicaoController,
                            decoration: const InputDecoration(labelText: 'Posição'),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            validator: (v) => (v == null || v.isEmpty) ? 'Inválido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Codigo>(
                      value: _codigo,
                      decoration: const InputDecoration(labelText: 'Código 1'),
                      items: Codigo.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _codigo = value);
                          _atualizarEstadoCampos();
                          _checkMultiplaFlow();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Codigo2?>(
                      value: isCodigoNormal ? null : _codigo2,
                      decoration: InputDecoration(
                        labelText: 'Código 2 (Opcional)',
                        filled: isCodigoNormal,
                        fillColor: isCodigoNormal ? Colors.grey.shade200 : null,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Nenhum')),
                        ...Codigo2.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                      ],
                      onChanged: isCodigoNormal ? null : (value) => setState(() => _codigo2 = value),
                    ),
                    const SizedBox(height: 16),

                    if (widget.isBio && _camposHabilitados)
                      Autocomplete<Especie>(
                        optionsBuilder: (textValue) async {
                          if (textValue.text.length < 2) return const Iterable<Especie>.empty();
                          return await _especieRepository.buscarPorNome(textValue.text);
                        },
                        displayStringForOption: (Especie o) => o.nomeComum,
                        onSelected: (selection) => _especieController.text = selection.nomeComum,
                        fieldViewBuilder: (ctx, ctrl, node, onComplete) {
                          if (_especieController.text.isNotEmpty && ctrl.text.isEmpty) ctrl.text = _especieController.text;
                          ctrl.addListener(() => _especieController.text = ctrl.text);
                          return TextFormField(
                            controller: ctrl,
                            focusNode: node,
                            onEditingComplete: onComplete,
                            decoration: const InputDecoration(
                              labelText: 'Espécie *', 
                              prefixIcon: Icon(Icons.spa, color: Colors.green)
                            ),
                            validator: (v) => (widget.isBio && (v == null || v.isEmpty)) ? 'Obrigatório' : null,
                          );
                        },
                      ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _capController,
                      enabled: _camposHabilitados,
                      decoration: const InputDecoration(labelText: 'CAP (cm)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (_camposHabilitados && (v == null || v.isEmpty)) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _alturaController,
                      enabled: _camposHabilitados,
                      decoration: InputDecoration(labelText: widget.isBio ? 'Altura Total (m) *' : 'Altura Total (m) - Opcional'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (widget.isBio && _camposHabilitados && (v == null || v.isEmpty)) ? 'Obrigatório em BIO' : null,
                    ),

                    if (showAlturaDano)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextFormField(
                          controller: _alturaDanoController,
                          enabled: _camposHabilitados,
                          decoration: const InputDecoration(labelText: 'Altura do Dano/Bifurcação (m)'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // SEÇÃO DE FOTO E FIM DE LINHA
                    Row(
                      children: [
                        // LÓGICA DE CARREGAMENTO NO BOTÃO DE FOTO
                        _processandoFoto 
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: SizedBox(
                                width: 30, 
                                height: 30, 
                                child: CircularProgressIndicator(strokeWidth: 3)
                              ),
                            )
                          : IconButton(
                              onPressed: _capturarFoto,
                              icon: const Icon(Icons.camera_alt, color: Color(0xFF023853), size: 40),
                              tooltip: "Tirar foto da árvore",
                            ),
                        
                        if (_fotosArvore.isNotEmpty && !_processandoFoto)
                          Text("${_fotosArvore.length} foto(s)", 
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                          ),
                        
                        const Spacer(),
                        
                        if (!widget.isEditing && !_isInMultiplaFlow)
                          Row(
                            children: [
                              const Text("Fim de linha?"),
                              Switch(
                                value: _fimDeLinha,
                                onChanged: (v) => setState(() => _fimDeLinha = v),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8.0,
                runSpacing: 8.0,
                children: widget.isEditing
                    ? [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                        TextButton(onPressed: () => _submit(atualizarEAnterior: true), child: const Text('Anterior')),
                        ElevatedButton(onPressed: () => _submit(), child: const Text('Atualizar')),
                        TextButton(onPressed: () => _submit(atualizarEProximo: true), child: const Text('Próximo')),
                      ]
                    : [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                        OutlinedButton(onPressed: () => _submit(mesmoFuste: true), child: const Text('Adic. Fuste')),
                        ElevatedButton(
                          onPressed: () => _submit(proxima: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary, 
                            foregroundColor: theme.colorScheme.onPrimary
                          ),
                          child: const Text('Salvar e Próximo'),
                        ),
                      ],
              )
            ],
          ),
        ),
      ),
    );
  }
}