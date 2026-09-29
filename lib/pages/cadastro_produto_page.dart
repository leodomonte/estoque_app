import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/produto.dart';
import '../models/lote.dart';
import '../models/prateleira.dart';
import '../data/estoque_database.dart';
import 'leitor_codigo_page.dart';

class CadastroProdutoPage extends StatefulWidget {
  final List<Produto> produtosExistentes;
  final Prateleira prateleira;
  final String? codigoInicial;

  const CadastroProdutoPage({
    super.key,
    required this.produtosExistentes,
    required this.prateleira,
    this.codigoInicial,
  });

  @override
  State<CadastroProdutoPage> createState() => _CadastroProdutoPageState();
}

class _CadastroProdutoPageState extends State<CadastroProdutoPage> {
  final nomeController = TextEditingController();
  final codigoController = TextEditingController();
  final loteController = TextEditingController();
  final quantidadeController = TextEditingController();

  DateTime? validade;

  @override
  void initState() {
    super.initState();
    codigoController.text = widget.codigoInicial ?? '';
    verificarCodigo();
  }

  @override
  void dispose() {
    nomeController.dispose();
    codigoController.dispose();
    loteController.dispose();
    quantidadeController.dispose();

    super.dispose();
  }

  Future<void> escolherValidade() async {
    final dataEscolhida = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (dataEscolhida != null) {
      setState(() {
        validade = dataEscolhida;
      });
    }
  }

  void verificarCodigo() {
    final codigo = codigoController.text;

    for (final produto in widget.produtosExistentes) {
      if (produto.codigo == codigo) {
        nomeController.text = produto.nome;
        return;
      }
    }
  }

  Future<void> _lerCodigoDeBarras() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LeitorCodigoPage()),
    );
    if (codigo == null || !mounted) return;
    codigoController.text = codigo;
    verificarCodigo();
  }

  Future<void> salvarProduto() async {
    if (nomeController.text.isEmpty ||
        codigoController.text.isEmpty ||
        loteController.text.isEmpty ||
        quantidadeController.text.isEmpty) {
      return;
    }

    if (validade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma calidade antes de salvar')),
      );
      return;
    }

    final lote = Lote(
      numero: loteController.text,
      validade: validade!,
      quantidade: int.tryParse(quantidadeController.text) ?? 0,
    );

    Produto? produtoExistente;

    for (final produto in widget.produtosExistentes) {
      if (produto.codigo == codigoController.text) {
        produtoExistente = produto;
        break;
      }
    }

    if (produtoExistente != null) {
      if (produtoExistente.prateleiraId != widget.prateleira.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este produto já está cadastrado em outra prateleira.',
            ),
          ),
        );
        return;
      }
      try {
        await EstoqueDatabase.instance.salvarProdutoComLote(
          produtoExistente,
          lote,
        );
        produtoExistente.lotes.add(lote);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível salvar. Verifique se o número do lote já existe.',
              ),
            ),
          );
        }
        return;
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    final produto = Produto(
      nome: nomeController.text,
      codigo: codigoController.text,
      prateleiraId: widget.prateleira.id,
      lotes: [lote],
    );

    try {
      await EstoqueDatabase.instance.salvarProdutoComLote(produto, lote);
      if (mounted) Navigator.pop(context, produto);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o produto.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Produto'), centerTitle: true),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do produto',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: codigoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  verificarCodigo();
                },
                decoration: InputDecoration(
                  labelText: 'Código',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Ler código pela câmera',
                    onPressed: _lerCodigoDeBarras,
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: loteController,
                decoration: const InputDecoration(
                  labelText: 'Número do lote',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: escolherValidade,
                  child: Text(
                    validade == null
                        ? 'Escolher validade'
                        : 'Validade: ${validade!.day.toString().padLeft(2, '0')}/'
                              '${validade!.month.toString().padLeft(2, '0')}/'
                              '${validade!.year}',
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: salvarProduto,
                  child: const Text('Salvar produto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
