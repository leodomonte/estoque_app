import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/estoque_database.dart';
import '../models/prateleira.dart';
import '../models/produto.dart';
import 'leitor_codigo_page.dart';

class EditarProdutoPage extends StatefulWidget {
  final Produto produto;

  const EditarProdutoPage({super.key, required this.produto});

  @override
  State<EditarProdutoPage> createState() => _EditarProdutoPageState();
}

class _EditarProdutoPageState extends State<EditarProdutoPage> {
  final _nomeController = TextEditingController();
  final _codigoController = TextEditingController();
  List<Prateleira> _prateleiras = [];
  int? _prateleiraSelecionada;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nomeController.text = widget.produto.nome;
    _codigoController.text = widget.produto.codigo;
    _prateleiraSelecionada = widget.produto.prateleiraId;
    _carregarPrateleiras();
  }

  Future<void> _carregarPrateleiras() async {
    try {
      final prateleiras = await EstoqueDatabase.instance.carregarPrateleiras();
      if (mounted) {
        setState(() {
          _prateleiras = prateleiras;
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _lerCodigo() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LeitorCodigoPage()),
    );
    if (codigo != null && mounted) _codigoController.text = codigo;
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    final novoCodigo = _codigoController.text.trim();
    final prateleiraId = _prateleiraSelecionada;
    if (nome.isEmpty || novoCodigo.isEmpty || prateleiraId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o nome, o código e a prateleira.'),
        ),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final codigoAntigo = widget.produto.codigo;
      await EstoqueDatabase.instance.atualizarProduto(
        codigoAntigo: codigoAntigo,
        novoCodigo: novoCodigo,
        nome: nome,
        prateleiraId: prateleiraId,
      );
      widget.produto
        ..codigo = novoCodigo
        ..nome = nome
        ..prateleiraId = prateleiraId;
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _salvando = false);
      final mensagem = erro.toString().contains('Já existe')
          ? 'Esse código já está sendo usado por outro produto.'
          : 'Não foi possível salvar as alterações.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagem)));
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar produto'), centerTitle: true),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _nomeController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nome do produto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _codigoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Código de barras',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Ler código pela câmera',
                          onPressed: _lerCodigo,
                          icon: const Icon(Icons.qr_code_scanner),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      initialValue: _prateleiraSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Prateleira',
                        border: OutlineInputBorder(),
                      ),
                      items: _prateleiras
                          .map(
                            (prateleira) => DropdownMenuItem<int>(
                              value: prateleira.id,
                              child: Text(prateleira.nome),
                            ),
                          )
                          .toList(),
                      onChanged: (id) => setState(() {
                        _prateleiraSelecionada = id;
                      }),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _salvando ? null : _salvar,
                        child: Text(
                          _salvando ? 'Salvando...' : 'Salvar alterações',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
