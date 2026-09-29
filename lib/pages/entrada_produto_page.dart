import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../data/estoque_database.dart';

class EntradaProdutoPage extends StatefulWidget {
  final Produto produto;

  const EntradaProdutoPage({super.key, required this.produto});

  @override
  State<EntradaProdutoPage> createState() => _EntradaProdutoPageState();
}

class _EntradaProdutoPageState extends State<EntradaProdutoPage> {
  int? loteSelecionado;
  final quantidadeController = TextEditingController();

  @override
  void dispose() {
    quantidadeController.dispose();
    super.dispose();
  }

  Future<void> confirmarEntrada() async {
    if (loteSelecionado == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecione um lote.')));
      return;
    }

    if (quantidadeController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Digite a quantidade.')));
      return;
    }

    final quantidade = int.tryParse(quantidadeController.text);

    if (quantidade == null || quantidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma quantidade válida.')),
      );
      return;
    }

    final lote = widget.produto.lotes[loteSelecionado!];

    lote.quantidade += quantidade;
    try {
      await EstoqueDatabase.instance.atualizarQuantidade(widget.produto, lote);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      lote.quantidade -= quantidade;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a entrada.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar estoque'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.produto.nome,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Selecione o lote:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<int>(
                initialValue: loteSelecionado,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Lote',
                ),
                items: List.generate(widget.produto.lotes.length, (index) {
                  final lote = widget.produto.lotes[index];

                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text('${lote.numero} — ${lote.quantidade} unidades'),
                  );
                }),
                onChanged: (valor) {
                  setState(() {
                    loteSelecionado = valor;
                  });
                },
              ),

              const SizedBox(height: 20),

              TextField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade da entrada',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: confirmarEntrada,
                  child: const Text('Confirmar entrada'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
