import 'package:flutter/material.dart';

import '../data/estoque_database.dart';
import '../models/lote.dart';
import '../models/produto.dart';
import 'editar_produto_page.dart';
import 'saida_produto_page.dart';
import 'entrada_produto_page.dart';
import 'adicionar_lote_page.dart';

class DetalhesProdutoPage extends StatefulWidget {
  final Produto produto;

  const DetalhesProdutoPage({super.key, required this.produto});

  @override
  State<DetalhesProdutoPage> createState() => _DetalhesProdutoPageState();
}

class _DetalhesProdutoPageState extends State<DetalhesProdutoPage> {
  Future<void> _adicionarLote() async {
    final lote = await Navigator.push<Lote>(
      context,
      MaterialPageRoute(
        builder: (_) => AdicionarLotePage(produto: widget.produto),
      ),
    );
    if (lote != null && mounted) {
      setState(() => widget.produto.lotes.add(lote));
    }
  }

  Future<void> _editarProduto() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarProdutoPage(produto: widget.produto),
      ),
    );
    if (atualizado == true && mounted) setState(() {});
  }

  Future<void> _confirmarExclusaoLote(Lote lote) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lote?'),
        content: Text(
          'O lote "${lote.numero}" e suas ${lote.quantidade} unidades '
          'serão removidos. O produto continuará cadastrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir lote'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    try {
      await EstoqueDatabase.instance.excluirLote(widget.produto, lote);
      if (mounted) {
        setState(() => widget.produto.lotes.remove(lote));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir o lote.')),
        );
      }
    }
  }

  Future<void> _confirmarExclusao() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text(
          'O produto "${widget.produto.nome}" e todos os seus lotes '
          'serão removidos do estoque. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    try {
      await EstoqueDatabase.instance.excluirProduto(widget.produto.codigo);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir o produto.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int quantidadeTotal = 0;

    for (final lote in widget.produto.lotes) {
      quantidadeTotal += lote.quantidade;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.produto.nome),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Editar produto',
            onPressed: _editarProduto,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Código: ${widget.produto.codigo}',
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 10),

              Text(
                'Quantidade total: $quantidadeTotal unidades',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Lotes',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _adicionarLote,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar lote'),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: widget.produto.lotes.length,
                  itemBuilder: (context, index) {
                    final lote = widget.produto.lotes[index];

                    final hoje = DateTime.now();
                    final diferenca = lote.validade.difference(hoje).inDays;

                    Color cor;
                    String mensagem;

                    if (lote.validade.isBefore(hoje)) {
                      cor = Colors.red;
                      mensagem = 'VENCIDO';
                    } else if (diferenca <= 30) {
                      cor = Colors.orange;
                      mensagem = 'Próximo do vencimento';
                    } else {
                      cor = Colors.green;
                      mensagem = 'Dentro da validade';
                    }

                    final data =
                        '${lote.validade.day.toString().padLeft(2, '0')}/'
                        '${lote.validade.month.toString().padLeft(2, '0')}/'
                        '${lote.validade.year}';

                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.inventory_2, color: cor),
                        title: Text('Lote: ${lote.numero}'),
                        subtitle: Text(
                          'Validade: $data\n$mensagem',
                          style: TextStyle(color: cor),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${lote.quantidade} un.',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Excluir lote',
                              onPressed: () => _confirmarExclusaoLote(lote),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EntradaProdutoPage(produto: widget.produto),
                      ),
                    );

                    setState(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar estoque'),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SaidaProdutoPage(produto: widget.produto),
                      ),
                    );

                    setState(() {});
                  },
                  icon: const Icon(Icons.remove),
                  label: const Text('Dar saída'),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmarExclusao,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir produto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
