import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/estoque_database.dart';
import 'models/lote.dart';
import 'models/prateleira.dart';
import 'models/produto.dart';
import 'pages/cadastro_produto_page.dart';
import 'pages/detalhes_produto_page.dart';
import 'pages/leitor_codigo_page.dart';
import 'pages/prateleiras_page.dart';
import 'pages/validades_page.dart';

void main() {
  runApp(const EstoqueApp());
}

class EstoqueApp extends StatefulWidget {
  const EstoqueApp({super.key});

  @override
  State<EstoqueApp> createState() => _EstoqueAppState();
}

class _EstoqueAppState extends State<EstoqueApp> {
  final _banco = EstoqueDatabase.instance;
  List<Prateleira> _prateleiras = [];
  List<Produto> _produtos = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  Future<void> _carregarProdutos() async {
    try {
      final prateleiras = await _banco.carregarPrateleiras();
      var produtos = await _banco.carregarProdutos();
      // Mantém os exemplos do app existente somente na primeira abertura.
      if (produtos.isEmpty) {
        final iniciais = <Produto>[
          Produto(
            codigo: '789123',
            nome: 'Leite Integral',
            prateleiraId: prateleiras.first.id,
            lotes: [
              Lote(
                numero: 'LT001',
                validade: DateTime(2026, 10, 10),
                quantidade: 20,
              ),
              Lote(
                numero: 'LT002',
                validade: DateTime(2026, 11, 20),
                quantidade: 15,
              ),
            ],
          ),
          Produto(
            codigo: '456789',
            nome: 'Arroz 5kg',
            prateleiraId: prateleiras.first.id,
            lotes: [
              Lote(
                numero: 'AR001',
                validade: DateTime(2027, 3, 15),
                quantidade: 35,
              ),
            ],
          ),
          Produto(
            codigo: '987654',
            nome: 'Feijão 1kg',
            prateleiraId: prateleiras.first.id,
            lotes: [
              Lote(
                numero: 'FJ001',
                validade: DateTime(2027, 1, 5),
                quantidade: 12,
              ),
            ],
          ),
        ];
        for (final produto in iniciais) {
          for (final lote in produto.lotes) {
            await _banco.salvarProdutoComLote(produto, lote);
          }
        }
        produtos = await _banco.carregarProdutos();
      }
      if (mounted) {
        setState(() {
          _prateleiras = prateleiras;
          _produtos = produtos;
          _carregando = false;
        });
      }
    } catch (erro) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = erro.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meu Estoque',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _carregando
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _erro != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Não foi possível abrir o banco de dados.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          _carregando = true;
                          _erro = null;
                          _carregarProdutos();
                        }),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : HomePage(
              prateleiras: _prateleiras,
              produtos: _produtos,
              aoVoltarDoEstoque: _carregarProdutos,
            ),
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Prateleira> prateleiras;
  final List<Produto> produtos;
  final Future<void> Function() aoVoltarDoEstoque;

  const HomePage({
    super.key,
    required this.prateleiras,
    required this.produtos,
    required this.aoVoltarDoEstoque,
  });

  Future<void> _escanearProduto(BuildContext context) async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LeitorCodigoPage()),
    );
    if (codigo == null || !context.mounted) return;

    Produto? produtoEncontrado;
    for (final produto in produtos) {
      if (produto.codigo == codigo) {
        produtoEncontrado = produto;
        break;
      }
    }

    if (produtoEncontrado != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalhesProdutoPage(produto: produtoEncontrado!),
        ),
      );
      if (context.mounted) await aoVoltarDoEstoque();
      return;
    }

    if (prateleiras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre uma prateleira primeiro.')),
      );
      return;
    }

    final prateleira = await showDialog<Prateleira>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Produto novo'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('Escolha a prateleira onde ele ficará.'),
          ),
          ...prateleiras.map(
            (item) => SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, item),
              child: Text(item.nome),
            ),
          ),
        ],
      ),
    );
    if (prateleira == null || !context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CadastroProdutoPage(
          produtosExistentes: produtos,
          prateleira: prateleira,
          codigoInicial: codigo,
        ),
      ),
    );
    if (context.mounted) await aoVoltarDoEstoque();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Estoque'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Controle de Estoque',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: () => _escanearProduto(context),
                  child: const Text('📷  Escanear produto'),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrateleirasPage(
                          prateleiras: prateleiras,
                          produtos: produtos,
                        ),
                      ),
                    );
                    await aoVoltarDoEstoque();
                  },
                  child: const Text('📦  Ver estoque'),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ValidadesPage(produtos: produtos),
                    ),
                  ),
                  child: const Text('⚠️  Ver validades'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
