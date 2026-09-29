import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/estoque_database.dart';
import '../models/lote.dart';
import '../models/produto.dart';

class AdicionarLotePage extends StatefulWidget {
  final Produto produto;

  const AdicionarLotePage({super.key, required this.produto});

  @override
  State<AdicionarLotePage> createState() => _AdicionarLotePageState();
}

class _AdicionarLotePageState extends State<AdicionarLotePage> {
  final _numeroController = TextEditingController();
  final _quantidadeController = TextEditingController();
  DateTime? _validade;
  bool _salvando = false;

  @override
  void dispose() {
    _numeroController.dispose();
    _quantidadeController.dispose();
    super.dispose();
  }

  Future<void> _escolherValidade() async {
    final hoje = DateUtils.dateOnly(DateTime.now());
    final data = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _validade ?? hoje,
      firstDate: hoje,
      lastDate: DateTime(2100),
    );
    if (data != null && mounted) setState(() => _validade = data);
  }

  Future<void> _salvar() async {
    final numero = _numeroController.text.trim();
    final quantidade = int.tryParse(_quantidadeController.text);
    if (numero.isEmpty || quantidade == null || quantidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe o número do lote e uma quantidade maior que zero.',
          ),
        ),
      );
      return;
    }
    if (_validade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha a validade do lote.')),
      );
      return;
    }

    final lote = Lote(
      numero: numero,
      validade: _validade!,
      quantidade: quantidade,
    );
    setState(() => _salvando = true);
    try {
      await EstoqueDatabase.instance.salvarProdutoComLote(widget.produto, lote);
      if (mounted) Navigator.pop(context, lote);
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar. Verifique se esse número de lote já existe.',
          ),
        ),
      );
    }
  }

  String _dataFormatada(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/'
      '${data.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar lote')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.produto.nome,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text('Código: ${widget.produto.codigo}'),
              const SizedBox(height: 20),
              TextField(
                controller: _numeroController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Número do lote',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: _escolherValidade,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _validade == null
                      ? 'Escolher validade'
                      : 'Validade: ${_dataFormatada(_validade!)}',
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _quantidadeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 25),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: const Icon(Icons.save_outlined),
                label: Text(_salvando ? 'Salvando...' : 'Salvar lote'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
