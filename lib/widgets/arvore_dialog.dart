// lib/widgets/arvore_dialog.dart (VERSÃO FINAL E CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:geoforestv1/models/arvore_model.dart';
import 'package:geoforestv1/models/especie_model.dart';
import 'package:geoforestv1/data/repositories/especie_repository.dart';
import 'package:geoforestv1/utils/image_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geoforestv1/models/codigo_florestal_model.dart';
import 'package:geoforestv1/data/repositories/codigos_repository.dart';

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
  
  final String projetoNome;
  final String fazendaNome;
  final String talhaoNome;
  final String idParcela;
  
  final String? atividadeTipo;

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
    this.atividadeTipo,
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

  List<CodigoFlorestal> _codigosDisponiveis = [];
  CodigoFlorestal? _regraAtual;
  bool _isLoadingCodigos = true;

  Codigo2? _codigo2;
  bool _fimDeLinha = false;
  
  List<String> _fotosArvore = [];
  bool _processandoFoto = false;

  @override
  void initState() {
    super.initState();
    
    _linhaController.text = widget.arvoreParaEditar?.linha.toString() ?? widget.linhaAtual.toString();
    _posicaoController.text = widget.arvoreParaEditar?.posicaoNaLinha.toString() ?? widget.posicaoNaLinhaAtual.toString();
    _fimDeLinha = widget.arvoreParaEditar?.fimDeLinha ?? false;
    _fotosArvore = List.from(widget.arvoreParaEditar?.photoPaths ?? []);

    if (widget.arvoreParaEditar != null) {
      _capController.text = (widget.arvoreParaEditar!.cap > 0) ? widget.arvoreParaEditar!.cap.toString().replaceAll('.', ',') : '';
      _alturaController.text = widget.arvoreParaEditar!.altura?.toString().replaceAll('.', ',') ?? '';
      _alturaDanoController.text = widget.arvoreParaEditar!.alturaDano?.toString().replaceAll('.', ',') ?? '';
      _especieController.text = widget.arvoreParaEditar!.especie ?? '';
      _codigo2 = widget.arvoreParaEditar!.codigo2;
    }

    _carregarRegras();
  }

  Future<void> _carregarRegras() async {
    String tipo = widget.atividadeTipo ?? "IPC"; 
    
    final repo = CodigosRepository();
    final dados = await repo.carregarCodigos(tipo);
    
    if (mounted) {
      setState(() {
        _codigosDisponiveis = dados;
        _isLoadingCodigos = false;
        
        if (widget.arvoreParaEditar != null) {
           final codAntigo = widget.arvoreParaEditar!.codigo.name;
           
           try {
             _regraAtual = _codigosDisponiveis.firstWhere(
               (c) => c.sigla.toUpperCase() == codAntigo.toUpperCase() || 
                      c.descricao.toUpperCase() == codAntigo.toUpperCase()
             );
           } catch (_) {
             _regraAtual = _codigosDisponiveis.isNotEmpty ? _codigosDisponiveis.first : null;
           }
        } else {
           _regraAtual = _codigosDisponiveis.isNotEmpty ? _codigosDisponiveis.first : null;
        }
        
        _aplicarRegrasAosCampos();
      });
    }
  }

  void _onCodigoChanged(CodigoFlorestal? novoCodigo) {
    if (novoCodigo == null) return;
    setState(() {
      _regraAtual = novoCodigo;
      _aplicarRegrasAosCampos();
    });
  }

  void _aplicarRegrasAosCampos() {
    if (_regraAtual == null) return;

    // 1. Regra de CAP
    if (_regraAtual!.isCapBloqueado) { // Use o getter correto do modelo
      _capController.text = "0"; 
    } else if (_capController.text == "0") {
      _capController.clear(); 
    }

    // 2. Regra de Altura Total
    if (_regraAtual!.isAlturaBloqueada) { // Use o getter correto
      _alturaController.text = ""; 
    }
    
    // 3. Regra de Altura Dano
    if (!_regraAtual!.requerAlturaDano) { // Use o getter correto
      _alturaDanoController.clear();
    }
  }

  Future<void> _capturarFoto() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 70, 
      maxWidth: 1200,   
      maxHeight: 1200,   
    );
    
    if (photo == null) return;

    setState(() => _processandoFoto = true);

    try {
      final linha = _linhaController.text.isEmpty ? "0" : _linhaController.text;
      final pos = _posicaoController.text.isEmpty ? "0" : _posicaoController.text;
      final String metadados = "Projeto: ${widget.projetoNome} | Fazenda: ${widget.fazendaNome} | Talhao: ${widget.talhaoNome} | Parcela: ${widget.idParcela} | L:$linha P:$pos";
      final nomeArquivo = "TREE_${widget.talhaoNome}_P${widget.idParcela}_L${linha}_P${pos}_${DateTime.now().millisecondsSinceEpoch}";

      await ImageUtils.carimbarMetadadosESalvar(
        pathOriginal: photo.path,
        informacoesHierarquia: metadados,
        nomeArquivoFinal: nomeArquivo,
      );

      setState(() {
        _fotosArvore.add(photo.path);
      });

    } catch (e) {
      debugPrint("Erro: $e");
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
      
      if (widget.isBio) {
        if (_especieController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Espécie é obrigatória.'), backgroundColor: Colors.red));
          return;
        }
      }

      final double cap = double.tryParse(_capController.text.replaceAll(',', '.')) ?? 0.0;
      final double? altura = _alturaController.text.isNotEmpty ? double.tryParse(_alturaController.text.replaceAll(',', '.')) : null;
      final double? alturaDano = _alturaDanoController.text.isNotEmpty ? double.tryParse(_alturaDanoController.text.replaceAll(',', '.')) : null;
      final int linha = int.tryParse(_linhaController.text) ?? widget.linhaAtual;
      final int posicao = int.tryParse(_posicaoController.text) ?? widget.posicaoNaLinhaAtual;

      // --- MAPEAMENTO PARA O ENUM (CÓDIGO DE BANCO) ---
      Codigo codigoParaSalvar = Codigo.Normal; 
      
      if (_regraAtual != null) {
        final sigla = _regraAtual!.sigla.toUpperCase();
        final desc = _regraAtual!.descricao.toUpperCase();

        try {
          codigoParaSalvar = Codigo.values.firstWhere((e) {
             final eName = e.name.toUpperCase();
             return eName == desc || eName == sigla;
          });
        } catch (_) {
          // --- MAPEAMENTO MANUAL PARA SIGLAS ESPECIAIS ---
          switch (sigla) {
            case 'A': codigoParaSalvar = Codigo.BifurcadaAcima; break;
            case 'B': case 'BF': codigoParaSalvar = Codigo.BifurcadaAbaixo; break;
            case 'CA': codigoParaSalvar = Codigo.Caida; break;
            case 'CR': codigoParaSalvar = Codigo.CaidaRaizVento; break;
            case 'D': codigoParaSalvar = Codigo.Dominada; break;
            case 'H': codigoParaSalvar = Codigo.DominanteAssmann; break;
            case 'J': codigoParaSalvar = Codigo.AtaqueMacacoJanela; break;
            case 'K': codigoParaSalvar = Codigo.AtaqueMacacoAnel; break;
            case 'L': codigoParaSalvar = Codigo.VespaMadeira; break;
            case 'M': codigoParaSalvar = Codigo.MortaOuSeca; break;
            case 'DS': codigoParaSalvar = Codigo.MarcadaDesbaste; break;
            case 'W': codigoParaSalvar = Codigo.DeitadaVento; break;
            case 'X': codigoParaSalvar = Codigo.FeridaBase; break;
            
            // Novos códigos BIO/Qualidade
            case 'I': 
                if (desc.contains("PRAGAS")) codigoParaSalvar = Codigo.PragasOuDoencas;
                else codigoParaSalvar = Codigo.Ingresso;
                break;
            case 'GRAE': codigoParaSalvar = Codigo.GramineaExotica; break;
            case 'GRAN': codigoParaSalvar = Codigo.GramineaNativa; break;
            case 'SOLE': codigoParaSalvar = Codigo.SoloExposto; break;
            case 'ARB': codigoParaSalvar = Codigo.Arbusto; break;
            case 'P2': codigoParaSalvar = Codigo.Peso2; break;
            case 'D3S': codigoParaSalvar = Codigo.DefeitoSup; break;
            case 'D3M': codigoParaSalvar = Codigo.DefeitoMed; break;
            case 'D3I': codigoParaSalvar = Codigo.DefeitoInf; break;
            case 'SUB': codigoParaSalvar = Codigo.SubAmostra; break;
            case 'SUE': codigoParaSalvar = Codigo.SubstEtiqueta; break;
            case 'GPS': codigoParaSalvar = Codigo.CodigoGPS; break;
            case 'AVA': codigoParaSalvar = Codigo.AmostraVazia; break;
            
            default: codigoParaSalvar = Codigo.Outro;
          }
        }
      }

      final arvore = Arvore(
        id: widget.arvoreParaEditar?.id,
        cap: cap,
        altura: altura,
        alturaDano: alturaDano,
        especie: _especieController.text.trim(), 
        linha: linha,
        posicaoNaLinha: posicao,
        codigo: codigoParaSalvar, 
        codigo2: codigoParaSalvar == Codigo.Normal ? null : _codigo2,
        fimDeLinha: _fimDeLinha,
        dominante: (_regraAtual?.permiteDominante ?? false) && (widget.arvoreParaEditar?.dominante ?? false),
        photoPaths: _fotosArvore, 
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
    
    // VARIÁVEIS DE CONTROLE VISUAL (VÊM DO CSV)
    bool capHabilitado = !(_regraAtual?.isCapBloqueado ?? false);
    bool alturaHabilitada = !(_regraAtual?.isAlturaBloqueada ?? false);
    bool mostraDano = _regraAtual?.requerAlturaDano ?? false;
    bool alturaObrigatoria = _regraAtual?.isAlturaObrigatoria ?? false;
    bool permiteFuste = (_regraAtual?.permiteMultifuste ?? false) || widget.isAdicionandoFuste;

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
              
              if (_isLoadingCodigos)
                const Center(child: CircularProgressIndicator())
              else
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LINHA E POSIÇÃO
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
                      
                      // DROPDOWN DINÂMICO (DO CSV)
                      DropdownButtonFormField<CodigoFlorestal>(
                        value: _regraAtual,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Código (Sigla)'),
                        items: _codigosDisponiveis.map((cod) {
                          return DropdownMenuItem(
                            value: cod,
                            child: Text("${cod.sigla} - ${cod.descricao}", overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _onCodigoChanged,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // CÓDIGO SECUNDÁRIO
                      DropdownButtonFormField<Codigo2?>(
                        value: (_regraAtual?.sigla == "N") ? null : _codigo2, 
                        decoration: const InputDecoration(
                          labelText: 'Código 2 (Opcional)',
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Nenhum')),
                          ...Codigo2.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                        ],
                        onChanged: (value) => setState(() => _codigo2 = value),
                      ),
                      const SizedBox(height: 16),

                      // ESPÉCIE (AUTOCOMPLETE)
                      if (widget.isBio)
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
                      
                      // CAP
                      TextFormField(
                        controller: _capController,
                        enabled: capHabilitado,
                        decoration: InputDecoration(
                          labelText: 'CAP (cm)',
                          filled: !capHabilitado,
                          fillColor: Colors.grey[200],
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (capHabilitado && (v == null || v.isEmpty)) ? 'Obrigatório' : null,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // ALTURA TOTAL
                      TextFormField(
                        controller: _alturaController,
                        enabled: alturaHabilitada,
                        decoration: InputDecoration(
                          labelText: 'Altura Total (m)', 
                          suffixText: alturaObrigatoria ? '*' : '',
                          filled: !alturaHabilitada,
                          fillColor: Colors.grey[200],
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (alturaObrigatoria && (v == null || v.isEmpty)) ? 'Altura Obrigatória' : null,
                      ),

                      // ALTURA DANO (DINÂMICO)
                      if (mostraDano)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: TextFormField(
                            controller: _alturaDanoController,
                            decoration: const InputDecoration(
                              labelText: 'Altura do Dano/Bifurcação (m)',
                              suffixIcon: Icon(Icons.warning_amber_rounded, color: Colors.orange)
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório para este código' : null,
                          ),
                        ),

                      const SizedBox(height: 16),

                      // SEÇÃO DE FOTO E FIM DE LINHA
                      Row(
                        children: [
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
                          
                          if (!widget.isEditing && !permiteFuste)
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
              
              // BOTÕES DE AÇÃO
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
                        
                        // Botão de Adicionar Fuste (só aparece se o CSV permitir)
                        if (permiteFuste)
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