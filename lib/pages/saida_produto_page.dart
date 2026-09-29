import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../data/estoque_database.dart';

class SaidaProdutoPage extends StatefulWidget {
  final Produto produto;

  const SaidaProdutoPage({super.key, required this.produto});

  @override
  State<SaidaProdutoPage> createState() => _SaidaProdutoPageState();
}

class _SaidaProdutoPageState extends State<SaidaProdutoPage> {
  int? loteSelecionado;
  final quantidadeController = TextEditingController();

  @override
  void dispose() {
    quantidadeController.dispose();
    super.dispose();
  }

  Future<void> confirmarSaida() async {
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

    if (quantidade > lote.quantidade) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A quantidade não pode ser maior que o estoque do lote.',
          ),
        ),
      );
      return;
    }

    lote.quantidade -= quantidade;
    try {
      await EstoqueDatabase.instance.atualizarQuantidade(widget.produto, lote);
      if (mounted) Navigator.pop(context, widget.produto);
    } catch (_) {
      lote.quantidade += quantidade;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a saída.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dar saída'), centerTitle: true),
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
                  labelText: 'Quantidade da saída',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: confirmarSaida,
                  child: const Text('Confirmar saída'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
