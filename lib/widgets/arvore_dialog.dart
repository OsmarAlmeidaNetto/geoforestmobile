// lib/widgets/arvore_dialog.dart

import 'package:flutter/material.dart';
import 'package:geoforestv1/models/arvore_model.dart';
import 'package:geoforestv1/models/especie_model.dart';
import 'package:geoforestv1/data/repositories/especie_repository.dart';

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
  final bool isBio; // Recebe se é BIO

  const ArvoreDialog({
    super.key,
    this.arvoreParaEditar,
    required this.linhaAtual,
    required this.posicaoNaLinhaAtual,
    this.isAdicionandoFuste = false,
    this.isBio = false, // Padrão é false
  });

  bool get isEditing => arvoreParaEditar != null && !isAdicionandoFuste;

  @override
  State<ArvoreDialog> createState() => _ArvoreDialogState();
}

class _ArvoreDialogState extends State<ArvoreDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
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
      
      // Carrega a espécie
      _especieController.text = arvore.especie ?? '';

      _codigo = arvore.codigo;
      _codigo2 = arvore.codigo2;
      _fimDeLinha = arvore.fimDeLinha;
      _linhaController.text = arvore.linha.toString();
      _posicaoController.text = arvore.posicaoNaLinha.toString();
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
        // Limpa espécie se não for edição
        if (!widget.isEditing) _especieController.clear();
      } else {
        _camposHabilitados = true;
        if (_capController.text == '0') {
          _capController.clear();
        }
      }
    });
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
      
      // --- VALIDAÇÃO EXTRA PARA BIO ---
      if (widget.isBio && _camposHabilitados) {
        if (_especieController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Para atividade BIO, a Espécie é obrigatória.'),
            backgroundColor: Colors.red,
          ));
          return;
        }
        // Validação de altura para BIO (se não tiver sido pega pelo validator do campo)
        if (_alturaController.text.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Para atividade BIO, a Altura é obrigatória.'),
            backgroundColor: Colors.red,
          ));
          return;
        }
      }
      // --------------------------------

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
        // SALVA A ESPÉCIE SE FOR BIO
        especie: widget.isBio ? _especieController.text.trim() : null, 
        linha: linha,
        posicaoNaLinha: posicao,
        codigo: _codigo,
        codigo2: _codigo == Codigo.Normal ? null : _codigo2,
        fimDeLinha: _fimDeLinha,
        dominante: widget.arvoreParaEditar?.dominante ?? false,
        capAuditoria: widget.arvoreParaEditar?.capAuditoria,
        alturaAuditoria: widget.arvoreParaEditar?.alturaAuditoria,
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
                  child: Text("Inventário BIO (Nativa)", textAlign: TextAlign.center, style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- LINHA E POSIÇÃO ---
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _linhaController,
                            enabled: true,
                            decoration: const InputDecoration(labelText: 'Linha'),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? 'Inválido' : null,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: TextFormField(
                            controller: _posicaoController,
                            enabled: true,
                            decoration: const InputDecoration(labelText: 'Posição'),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? 'Inválido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // --- CÓDIGOS ---
                    DropdownButtonFormField<Codigo>(
                      value: _codigo,
                      decoration: const InputDecoration(labelText: 'Código 1'),
                      items: Codigo.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _codigo = value;
                            if (value == Codigo.Normal) {
                              _codigo2 = null;
                            }
                          });
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

                    // --- [BIO] AUTOCOMPLETE DE ESPÉCIE ---
                    // Esta parte estava faltando no seu código.
                    if (widget.isBio && _camposHabilitados)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Autocomplete<Especie>(
                            optionsBuilder: (TextEditingValue textEditingValue) async {
                              if (textEditingValue.text.length < 2) {
                                return const Iterable<Especie>.empty();
                              }
                              // Chama o repositório que busca no banco local
                              return await _especieRepository.buscarPorNome(textEditingValue.text);
                            },
                            displayStringForOption: (Especie option) => option.nomeComum,
                            onSelected: (Especie selection) {
                              // Salva a seleção no controller
                              _especieController.text = selection.nomeComum; 
                            },
                            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                              // Mantém o texto sincronizado caso seja edição
                              if (_especieController.text.isNotEmpty && controller.text.isEmpty) {
                                controller.text = _especieController.text;
                              }
                              // Ouve mudanças manuais
                              controller.addListener(() {
                                _especieController.text = controller.text;
                              });
                              
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                onEditingComplete: onEditingComplete,
                                decoration: const InputDecoration(
                                  labelText: 'Espécie *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.spa, color: Colors.green),
                                  suffixIcon: Icon(Icons.search),
                                  helperText: 'Digite para buscar na lista',
                                ),
                                validator: (v) {
                                  if (widget.isBio && (v == null || v.isEmpty)) return 'Obrigatório';
                                  return null;
                                },
                              );
                            },
                          );
                        }),
                      ),

                    // --- CAP ---
                    TextFormField(
                      controller: _capController,
                      enabled: _camposHabilitados,
                      decoration: const InputDecoration(labelText: 'CAP (cm)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (_camposHabilitados && (value == null || value.isEmpty)) {
                          return 'Campo obrigatório';
                        }
                        if (value != null && value.isNotEmpty && double.tryParse(value.replaceAll(',', '.')) == null) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- ALTURA (COM VALIDAÇÃO CONDICIONAL) ---
                    TextFormField(
                      controller: _alturaController,
                      enabled: _camposHabilitados,
                      // Muda o rótulo visualmente se for BIO
                      decoration: InputDecoration(
                        labelText: widget.isBio ? 'Altura Total (m) *' : 'Altura Total (m) - Opcional',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        // Regra de validação para BIO
                        if (widget.isBio && _camposHabilitados) {
                          if (value == null || value.isEmpty) {
                            return 'Altura é obrigatória em BIO';
                          }
                        }
                        return null;
                      },
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

                    if (!widget.isEditing && !_isInMultiplaFlow)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SwitchListTile(
                          title: const Text('Fim da linha de plantio?'),
                          value: _fimDeLinha,
                          onChanged: (value) => setState(() => _fimDeLinha = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // --- BOTÕES DE AÇÃO ---
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
                    : _isInMultiplaFlow
                      ? [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                          ElevatedButton(onPressed: () => _submit(mesmoFuste: true), child: const Text('Adic. Fuste')),
                          ElevatedButton(
                            onPressed: () => _submit(proxima: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                            ),
                            child: const Text('Salvar e Próximo'),
                          ),
                        ]
                      : [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                          OutlinedButton(onPressed: () => _submit(mesmoFuste: true), child: const Text('Adic. Fuste')),
                          ElevatedButton(
                            onPressed: () => _submit(proxima: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
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