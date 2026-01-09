// lib/providers/gerente_provider.dart (VERSÃO COM LAZY LOADING)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestv1/data/repositories/atividade_repository.dart';
import 'package:geoforestv1/data/repositories/projeto_repository.dart';
import 'package:geoforestv1/data/repositories/talhao_repository.dart';
import 'package:geoforestv1/models/atividade_model.dart';
import 'package:geoforestv1/models/cubagem_arvore_model.dart';
import 'package:geoforestv1/models/diario_de_campo_model.dart';
import 'package:geoforestv1/models/parcela_model.dart';
import 'package:geoforestv1/models/projeto_model.dart';
import 'package:geoforestv1/models/talhao_model.dart';
import 'package:geoforestv1/services/gerente_service.dart';
import 'package:geoforestv1/services/licensing_service.dart';
import 'package:intl/date_symbol_data_local.dart';

class GerenteProvider with ChangeNotifier {
  final GerenteService _gerenteService = GerenteService();
  final ProjetoRepository _projetoRepository = ProjetoRepository();
  final TalhaoRepository _talhaoRepository = TalhaoRepository();
  final AtividadeRepository _atividadeRepository = AtividadeRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LicensingService _licensingService = LicensingService();

  // Streams
  StreamSubscription? _dadosColetaSubscription;
  StreamSubscription? _dadosCubagemSubscription;
  StreamSubscription? _dadosDiarioSubscription;

  // Dados Transacionais (PESADOS - Carregados sob demanda)
  List<Parcela> _parcelasSincronizadas = [];
  List<CubagemArvore> _cubagensSincronizadas = [];
  
  // Dados Globais (Médios - Mantidos globais para o Dashboard de Operações)
  List<DiarioDeCampo> _diariosSincronizados = [];

  // Dados Estruturais (LEVES - Carregados no início)
  List<Projeto> _projetos = [];
  List<Atividade> _atividades = [];
  List<Talhao> _talhoes = [];

  // Mapas Auxiliares
  Map<int, int> _talhaoToProjetoMap = {};
  Map<int, int> _talhaoToAtividadeMap = {};
  Map<int, String> _talhaoIdToNomeMap = {};
  Map<String, String> _fazendaIdToNomeMap = {};

  // Estado
  bool _isLoading = false;
  String? _error;
  int? _projetoSelecionadoId; // Rastreia qual projeto está na memória

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Projeto> get projetos => _projetos;
  List<Atividade> get atividades => _atividades;
  List<Talhao> get talhoes => _talhoes;
  
  // Estes getters agora retornam apenas dados do projeto selecionado
  List<Parcela> get parcelasSincronizadas => _parcelasSincronizadas;
  List<CubagemArvore> get cubagensSincronizadas => _cubagensSincronizadas;
  
  List<DiarioDeCampo> get diariosSincronizados => _diariosSincronizados;
  
  Map<int, int> get talhaoToProjetoMap => _talhaoToProjetoMap;
  Map<int, int> get talhaoToAtividadeMap => _talhaoToAtividadeMap;
  
  // Getter para saber qual projeto está carregado
  int? get projetoCarregadoId => _projetoSelecionadoId;

  GerenteProvider() {
    initializeDateFormatting('pt_BR', null);
  }

  /// Busca licenças delegadas (mantido igual)
  Future<Set<String>> _getDelegatedLicenseIds() async {
    final projetosLocais = await _projetoRepository.getTodosOsProjetosParaGerente();
    return projetosLocais
        .where((p) => p.delegadoPorLicenseId != null)
        .map((p) => p.delegadoPorLicenseId!)
        .toSet();
  }

  /// ETAPA 1: CARGA ESTRUTURAL (Leve)
  /// Chamado no initState do Dashboard ou Home. Carrega apenas nomes e IDs.
  Future<void> iniciarMonitoramentoEstrutural() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Usuário não autenticado.");

      // 1. Carrega Estrutura Local (SQLite) ou Nuvem
      _projetos = await _projetoRepository.getTodosOsProjetosParaGerente();
      _projetos.sort((a, b) => a.nome.compareTo(b.nome));
      
      _atividades = await _atividadeRepository.getTodasAsAtividades();
      _talhoes = await _talhaoRepository.getTodosOsTalhoes();
      
      await _buildAuxiliaryMaps();

      // 2. Prepara Licenças para monitoramento de Diários
      final licenseDoc = await _licensingService.findLicenseDocumentForUser(user);
      final ownLicenseId = licenseDoc?.id;
      final delegatedLicenseIds = await _getDelegatedLicenseIds();
      final allLicenseIds = {if(ownLicenseId != null) ownLicenseId, ...delegatedLicenseIds}.toList();

      // 3. Monitora Diários (Mantido global pois é usado no Dashboard de Operações)
      _dadosDiarioSubscription?.cancel();
      _dadosDiarioSubscription = _gerenteService.getDadosDiarioStream(licenseIds: allLicenseIds).listen(
        (listaDeDiarios) {
          _diariosSincronizados = listaDeDiarios;
          notifyListeners();
        },
        onError: (e) => debugPrint("Erro stream diários: $e"),
      );

      _isLoading = false;
      notifyListeners();

    } catch (e) {
      _error = "Erro ao carregar estrutura: $e";
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ETAPA 2: CARGA SOB DEMANDA (Pesada)
  /// Chamado quando o usuário seleciona um projeto no Dropdown.
  Future<void> carregarDadosDoProjeto(int projetoId) async {
    // Se já está carregado, não faz nada
    if (_projetoSelecionadoId == projetoId) return;

    _isLoading = true;
    
    // 1. LIMPEZA DA MEMÓRIA
    _parcelasSincronizadas = [];
    _cubagensSincronizadas = [];
    _dadosColetaSubscription?.cancel();
    _dadosCubagemSubscription?.cancel();
    _projetoSelecionadoId = projetoId;
    
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final licenseDoc = await _licensingService.findLicenseDocumentForUser(user);
      final ownLicenseId = licenseDoc?.id;
      final delegatedLicenseIds = await _getDelegatedLicenseIds();
      final allLicenseIds = {if(ownLicenseId != null) ownLicenseId, ...delegatedLicenseIds}.toList();

      debugPrint(">>> Carregando dados pesados APENAS para o projeto ID: $projetoId");

      // 2. Stream de Parcelas (Filtrado pelo ID do Projeto no Firestore)
      _dadosColetaSubscription = _gerenteService.getParcelasDoProjetoStream(
        licenseIds: allLicenseIds, 
        projetoId: projetoId
      ).listen((listaDeParcelas) async {
        
        // Mapeamento de nomes (Enrichment)
        _parcelasSincronizadas = listaDeParcelas.map((p) {
          final nomeFazenda = _fazendaIdToNomeMap[p.idFazenda] ?? p.nomeFazenda;
          final nomeTalhao = _talhaoIdToNomeMap[p.talhaoId] ?? p.nomeTalhao;
          // O projetoId já vem filtrado, mas garantimos
          final projId = p.projetoId ?? projetoId; 
          
          final atividadeId = _talhaoToAtividadeMap[p.talhaoId];
          // Encontra o tipo da atividade
          final tipoAtividade = atividadeId != null 
              ? _atividades.firstWhere((a) => a.id == atividadeId, orElse: () => Atividade(projetoId: 0, tipo: '', descricao: '', dataCriacao: DateTime.now())).tipo 
              : null;

          return p.copyWith(
            nomeFazenda: nomeFazenda, 
            nomeTalhao: nomeTalhao,
            projetoId: projId,
            atividadeTipo: tipoAtividade,
          );
        }).toList();

        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = "Erro ao baixar parcelas: $e";
        _isLoading = false;
        notifyListeners();
      });

      // 3. Stream de Cubagens (Filtrado pelos Talhões do Projeto)
      // Primeiro, descobrimos quais talhões pertencem a este projeto
      final atividadesDoProjetoIds = _atividades
          .where((a) => a.projetoId == projetoId)
          .map((a) => a.id)
          .toSet();
      
      final talhoesDoProjetoIds = _talhoes
          .where((t) => atividadesDoProjetoIds.contains(t.fazendaAtividadeId))
          .map((t) => t.id!)
          .toList();

      if (talhoesDoProjetoIds.isNotEmpty) {
        _dadosCubagemSubscription = _gerenteService.getCubagensDoProjetoStream(
          licenseIds: allLicenseIds, 
          talhoesIds: talhoesDoProjetoIds // Filtro aplicado aqui
        ).listen((listaDeCubagens) {
          _cubagensSincronizadas = listaDeCubagens;
          notifyListeners();
        }, onError: (e) => debugPrint("Erro ao baixar cubagens: $e"));
      } else {
        _cubagensSincronizadas = [];
        notifyListeners();
      }

    } catch (e) {
      _error = "Erro ao carregar projeto: $e";
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpa os dados pesados da memória (útil ao sair do dashboard)
  void limparProjetoSelecionado() {
    _dadosColetaSubscription?.cancel();
    _dadosCubagemSubscription?.cancel();
    _parcelasSincronizadas = [];
    _cubagensSincronizadas = [];
    _projetoSelecionadoId = null;
    notifyListeners();
  }

  // Mantido igual para auxiliar nos nomes
  Future<void> _buildAuxiliaryMaps() async {
    _talhoes = await _talhaoRepository.getTodosOsTalhoes();
    _talhaoToProjetoMap = { for (var talhao in _talhoes) if (talhao.id != null && talhao.projetoId != null) talhao.id!: talhao.projetoId! };
    _talhaoToAtividadeMap = { for (var talhao in _talhoes) if (talhao.id != null) talhao.id!: talhao.fazendaAtividadeId };
    _talhaoIdToNomeMap = { for (var talhao in _talhoes) if (talhao.id != null) talhao.id!: talhao.nome };
    _fazendaIdToNomeMap = { for (var talhao in _talhoes) if (talhao.fazendaId.isNotEmpty && talhao.fazendaNome != null) talhao.fazendaId: talhao.fazendaNome! };
  }

  @override
  void dispose() {
    _dadosColetaSubscription?.cancel();
    _dadosCubagemSubscription?.cancel();
    _dadosDiarioSubscription?.cancel();
    super.dispose();
  }
}