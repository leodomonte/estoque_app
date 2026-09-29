import 'package:flutter/material.dart';

import '../data/estoque_database.dart';
import '../models/prateleira.dart';
import '../models/produto.dart';
import 'estoque_page.dart';

class PrateleirasPage extends StatefulWidget {
  final List<Prateleira> prateleiras;
  final List<Produto> produtos;

  const PrateleirasPage({
    super.key,
    required this.prateleiras,
    required this.produtos,
  });

  @override
  State<PrateleirasPage> createState() => _PrateleirasPageState();
}

class _PrateleirasPageState extends State<PrateleirasPage> {
  late List<Prateleira> _prateleiras = widget.prateleiras;
  late List<Produto> _produtos = widget.produtos;

  Future<void> _recarregar() async {
    final banco = EstoqueDatabase.instance;
    final prateleiras = await banco.carregarPrateleiras();
    final produtos = await banco.carregarProdutos();
    if (mounted) {
      setState(() {
        _prateleiras = prateleiras;
        _produtos = produtos;
      });
    }
  }

  Future<void> _adicionarPrateleira() async {
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => const _NovaPrateleiraDialog(),
    );
    if (nome == null || nome.trim().isEmpty) return;

    final nomeLimpo = nome.trim();
    if (_prateleiras.any(
      (prateleira) => prateleira.nome.toLowerCase() == nomeLimpo.toLowerCase(),
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Já existe uma prateleira com esse nome.'),
          ),
        );
      }
      return;
    }

    try {
      final id = await EstoqueDatabase.instance.criarPrateleira(nomeLimpo);
      if (mounted) {
        setState(() {
          _prateleiras = [..._prateleiras, Prateleira(id: id, nome: nomeLimpo)];
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar a prateleira.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(Prateleira prateleira) async {
    if (prateleira.id == EstoqueDatabase.prateleiraGeralId) return;

    final quantidadeProdutos = _produtos
        .where((produto) => produto.prateleiraId == prateleira.id)
        .length;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir prateleira?'),
        content: Text(
          quantidadeProdutos == 0
              ? 'A prateleira "${prateleira.nome}" será removida.'
              : 'A prateleira "${prateleira.nome}" será removida. '
                    'Seus $quantidadeProdutos produtos serão movidos para '
                    'Prateleira geral.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir prateleira'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      final movidos = await EstoqueDatabase.instance.excluirPrateleira(
        prateleira.id,
      );
      if (!mounted) return;
      setState(() {
        _prateleiras = _prateleiras
            .where((item) => item.id != prateleira.id)
            .toList();
        _produtos = _produtos.map((produto) {
          if (produto.prateleiraId != prateleira.id) return produto;
          return Produto(
            codigo: produto.codigo,
            nome: produto.nome,
            prateleiraId: EstoqueDatabase.prateleiraGeralId,
            lotes: produto.lotes,
          );
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            movidos == 0
                ? 'Prateleira excluída.'
                : 'Prateleira excluída; $movidos produtos foram para Prateleira geral.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir a prateleira.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prateleiras'), centerTitle: true),
      body: _prateleiras.isEmpty
          ? const Center(child: Text('Nenhuma prateleira cadastrada.'))
          : ListView.builder(
              itemCount: _prateleiras.length,
              itemBuilder: (context, index) {
                final prateleira = _prateleiras[index];
                final quantidade = _produtos
                    .where((produto) => produto.prateleiraId == prateleira.id)
                    .length;
                return ListTile(
                  leading: const Icon(Icons.shelves),
                  title: Text(prateleira.nome),
                  subtitle: Text('$quantidade produtos'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip:
                            prateleira.id == EstoqueDatabase.prateleiraGeralId
                            ? 'Prateleira geral não pode ser excluída'
                            : 'Excluir prateleira',
                        onPressed:
                            prateleira.id == EstoqueDatabase.prateleiraGeralId
                            ? null
                            : () => _confirmarExclusao(prateleira),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EstoquePage(
                          prateleira: prateleira,
                          produtos: _produtos,
                        ),
                      ),
                    );
                    await _recarregar();
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarPrateleira,
        icon: const Icon(Icons.add),
        label: const Text('Nova prateleira'),
      ),
    );
  }
}

class _NovaPrateleiraDialog extends StatefulWidget {
  const _NovaPrateleiraDialog();

  @override
  State<_NovaPrateleiraDialog> createState() => _NovaPrateleiraDialogState();
}

class _NovaPrateleiraDialogState extends State<_NovaPrateleiraDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova prateleira'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nome da prateleira'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
