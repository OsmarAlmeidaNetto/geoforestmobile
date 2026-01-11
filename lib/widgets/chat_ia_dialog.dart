// lib/widgets/chat_ia_dialog.dart

import 'package:flutter/material.dart';
import 'package:geoforestv1/models/arvore_model.dart';
import 'package:geoforestv1/models/parcela_model.dart';
import 'package:geoforestv1/services/ai_validation_service.dart';

class ChatIaDialog extends StatefulWidget {
  final Parcela parcela;
  final List<Arvore> arvores;

  const ChatIaDialog({super.key, required this.parcela, required this.arvores});

  @override
  State<ChatIaDialog> createState() => _ChatIaDialogState();
}

class _ChatIaDialogState extends State<ChatIaDialog> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _aiService = AiValidationService();
  
  final List<Map<String, String>> _mensagens = [
    {
      "role": "ai",
      "text": "Olá! Sou a IA do GeoForest. Analisei os dados desta parcela. Posso verificar erros, calcular médias ou tirar dúvidas. O que deseja?"
    }
  ];
  
  bool _isLoading = false;

  // --- MAPA DE PROMPTS DETALHADOS ---
  // Aqui traduzimos o botão curto para uma ordem técnica completa
  final Map<String, String> _promptsTecnicos = {
  "🔍 Analisar Erros": "Atue como auditor de qualidade. Analise os dados JSON enviados e liste especificamente: 1. Árvores com CAP zerado que não sejam falha/morta. 2. Árvores com CAP muito acima da média (outliers). 3. Erros de sequência na numeração de Linha/Posição.",
    
    "📊 Resumo Estatístico": "Gere um resumo dendrométrico contendo: 1. Média Aritmética do CAP. 2. Altura Média. 3. Contagem total de fustes. 4. Contagem por tipo de código.",
    
    "🌲 Dominantes": "Identifique quais árvores são prováveis dominantes baseadas no maior CAP. Liste as 5 árvores com maior CAP desta parcela.",
    
    // --- NOVO COMANDO PODEROSO ---
    "🌿 Analisar Espécies": """
      Faça uma análise fitossociológica e ecológica simplificada desta parcela baseada nos nomes no campo 'especie':
      1. Riqueza: Quantas espécies diferentes foram encontradas?
      2. Dominância: Quais são as 3 espécies mais abundantes (maior quantidade)?
      3. Raridade na Amostra: Quais espécies apareceram apenas 1 vez (singletons)?
      4. Status Ecológico/Legal: Verifique na sua base de conhecimento se alguma das espécies listadas é considerada 'Madeira de Lei' no Brasil, está em lista de extinção (IBAMA/IUCN) ou tem alto valor comercial.
      5. Conclusão: A parcela apresenta alta ou baixa diversidade baseada nesta amostra?
    """
  };

  void _enviarPergunta({String? textoVisivel}) async {
    // O que aparece no balãozinho do chat (ex: "Analisar Erros")
    final textoParaExibir = textoVisivel ?? _controller.text;
    
    if (textoParaExibir.isEmpty) return;

    // O que a IA realmente vai ler (A ordem técnica completa)
    // Se não tiver no mapa, usa o próprio texto digitado pelo usuário
    final textoParaIA = _promptsTecnicos[textoParaExibir] ?? textoParaExibir;
    
    setState(() {
      _mensagens.add({"role": "user", "text": textoParaExibir});
      _isLoading = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final respostaIa = await _aiService.perguntarSobreDados(
        textoParaIA, // <--- Envia o comando detalhado
        widget.parcela, 
        widget.arvores
      );

      if (mounted) {
        setState(() {
          _mensagens.add({"role": "ai", "text": respostaIa});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensagens.add({"role": "ai", "text": "Ocorreu um erro ao processar. Tente novamente."});
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBio = widget.parcela.atividadeTipo?.toUpperCase().contains("BIO") ?? false;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          const Text("GeoForest AI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                constraints: const BoxConstraints(maxHeight: 350),
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: _mensagens.length,
                  itemBuilder: (context, index) {
                    final msg = _mensagens[index];
                    final isAi = msg["role"] == "ai";
                    return _buildBubble(msg["text"]!, isAi);
                  },
                ),
              ),
            ),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(backgroundColor: Colors.transparent),
              ),

            const SizedBox(height: 12),

            // Botões de Ação Rápida
            if (!_isLoading)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickAction("🔍 Analisar Erros"),
                    _buildQuickAction("📊 Resumo Estatístico"),
                    
                    if (!isBio) // Só mostra Dominantes se NÃO for Bio (geralmente Bio não foca nisso)
                       _buildQuickAction("🌲 Dominantes"),
                    
                    if (isBio) // Só mostra Espécies se FOR Bio
                       _buildQuickAction("🌿 Analisar Espécies"),
                  ],
                ),
              ),
              
            const SizedBox(height: 12),

            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Digite sua dúvida...",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _isLoading ? null : () => _enviarPergunta(),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _enviarPergunta(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fechar"))
      ],
    );
  }

  Widget _buildBubble(String texto, bool isAi) {
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAi ? Colors.grey.shade100 : Colors.blue.shade600,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isAi ? 0 : 12),
            bottomRight: Radius.circular(isAi ? 12 : 0),
          ),
          border: isAi ? Border.all(color: Colors.grey.shade300) : null,
        ),
        child: Text(
          texto,
          style: TextStyle(color: isAi ? Colors.black87 : Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        // Passa o label como texto visível
        onPressed: _isLoading ? null : () => _enviarPergunta(textoVisivel: label),
        backgroundColor: Colors.blue.shade50,
        side: BorderSide(color: Colors.blue.shade200),
      ),
    );
  }
}