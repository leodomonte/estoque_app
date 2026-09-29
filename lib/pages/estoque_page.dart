import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../models/prateleira.dart';
import 'cadastro_produto_page.dart';
import 'detalhes_produto_page.dart';

class EstoquePage extends StatefulWidget {
  final Prateleira prateleira;
  final List<Produto> produtos;

  const EstoquePage({
    super.key,
    required this.prateleira,
    required this.produtos,
  });

  @override
  State<EstoquePage> createState() => _EstoquePageState();
}

class _EstoquePageState extends State<EstoquePage> {
  @override
  Widget build(BuildContext context) {
    final produtosDaPrateleira = widget.produtos
        .where((produto) => produto.prateleiraId == widget.prateleira.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.prateleira.nome), centerTitle: true),

      body: produtosDaPrateleira.isEmpty
          ? const Center(child: Text('Esta prateleira ainda está vazia.'))
          : ListView.builder(
              itemCount: produtosDaPrateleira.length,
              itemBuilder: (context, index) {
                final produto = produtosDaPrateleira[index];

                int quantidadeTotal = 0;

                for (final lote in produto.lotes) {
                  quantidadeTotal += lote.quantidade;
                }

                return ListTile(
                  leading: const Icon(Icons.inventory_2),

                  title: Text(produto.nome),

                  subtitle: Text(
                    'Código: ${produto.codigo}\n'
                    'Lotes: ${produto.lotes.length}',
                  ),

                  trailing: Text(
                    '$quantidadeTotal un.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  onTap: () async {
                    final excluido = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetalhesProdutoPage(produto: produto),
                      ),
                    );

                    if (excluido == true) {
                      setState(() {
                        widget.produtos.removeWhere(
                          (item) => item.codigo == produto.codigo,
                        );
                      });
                    } else if (mounted) {
                      setState(() {});
                    }
                  },
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final produto = await Navigator.push<Produto>(
            context,
            MaterialPageRoute(
              builder: (context) => CadastroProdutoPage(
                produtosExistentes: widget.produtos,
                prateleira: widget.prateleira,
              ),
            ),
          );

          if (produto != null) {
            setState(() {
              final index = widget.produtos.indexWhere(
                (p) => p.codigo == produto.codigo,
              );

              if (index >= 0) {
                widget.produtos[index].lotes.addAll(produto.lotes);
              } else {
                widget.produtos.add(produto);
              }
            });
          } else if (mounted) {
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
