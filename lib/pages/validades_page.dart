import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/estoque_database.dart';
import '../models/lote.dart';
import '../models/produto.dart';
import 'detalhes_produto_page.dart';

class ValidadesPage extends StatefulWidget {
  final List<Produto> produtos;

  const ValidadesPage({super.key, required this.produtos});

  @override
  State<ValidadesPage> createState() => _ValidadesPageState();
}

class _ValidadesPageState extends State<ValidadesPage> {
  late final List<Produto> _produtos = List.of(widget.produtos);
  bool _compartilhando = false;

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/'
      '${data.year}';

  DateTime _dataSemHora(DateTime data) =>
      DateTime(data.year, data.month, data.day);

  List<(Produto, Lote)> _lotesProximosDoVencimento() {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final limite = hoje.add(const Duration(days: 90));
    final proximos = <(Produto, Lote)>[];

    for (final produto in _produtos) {
      if (produto.prateleiraId == EstoqueDatabase.prateleiraGeralId) continue;

      for (final lote in produto.lotes) {
        final validade = _dataSemHora(lote.validade);
        if (validade.isBefore(hoje) || validade.isAfter(limite)) continue;
        proximos.add((produto, lote));
      }
    }

    proximos.sort((a, b) {
      return a.$2.validade.compareTo(b.$2.validade);
    });
    return proximos;
  }

  Future<void> _compartilharLista() async {
    if (_compartilhando) return;

    final proximos = _lotesProximosDoVencimento();
    if (proximos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há lotes vencendo nos próximos 90 dias.'),
        ),
      );
      return;
    }

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final limite = hoje.add(const Duration(days: 90));
    final texto = StringBuffer()
      ..writeln('*PRODUTOS PRÓXIMOS DO VENCIMENTO*')
      ..writeln('Período: ${_formatarData(hoje)} a ${_formatarData(limite)}')
      ..writeln('');

    for (var i = 0; i < proximos.length; i++) {
      final (produto, lote) = proximos[i];
      final diasParaVencer = _dataSemHora(lote.validade)
          .difference(hoje)
          .inDays;
      final unidadeDias = diasParaVencer == 1 ? 'dia' : 'dias';
      texto
        ..writeln('${i + 1}. ${produto.nome}')
        ..writeln('   Código: ${produto.codigo}')
        ..writeln('   Lote: ${lote.numero}')
        ..writeln(
          '   Validade: ${_formatarData(lote.validade)} '
          '($diasParaVencer $unidadeDias para vencer)',
        )
        ..writeln('   Quantidade: ${lote.quantidade} un.')
        ..writeln('');
    }
    texto.writeln('Total: ${proximos.length} lotes');

    setState(() => _compartilhando = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Produtos próximos do vencimento',
          files: [
            XFile.fromData(
              utf8.encode(texto.toString()),
              mimeType: 'text/plain',
            ),
          ],
          fileNameOverrides: const ['produtos_proximos_do_vencimento.txt'],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível compartilhar a lista.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _compartilhando = false);
    }
  }

  Future<void> _abrirProduto(Produto produto) async {
    final excluido = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetalhesProdutoPage(produto: produto)),
    );

    if (!mounted) return;
    setState(() {
      if (excluido == true) _produtos.remove(produto);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> lotes = [];

    for (final produto in _produtos) {
      if (produto.prateleiraId == EstoqueDatabase.prateleiraGeralId) {
        continue;
      }
      for (final lote in produto.lotes) {
        lotes.add({'produto': produto, 'lote': lote});
      }
    }

    lotes.sort((a, b) {
      final loteA = a['lote'];
      final loteB = b['lote'];

      return loteA.validade.compareTo(loteB.validade);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validades'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Compartilhar lista de validade',
            onPressed: _compartilhando ? null : _compartilharLista,
            icon: _compartilhando
                ? const Icon(Icons.hourglass_top)
                : const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: lotes.length,
        itemBuilder: (context, index) {
          final produto = lotes[index]['produto'] as Produto;
          final lote = lotes[index]['lote'];

          final hoje = _dataSemHora(DateTime.now());
          final validade = _dataSemHora(lote.validade);
          final diferenca = validade.difference(hoje).inDays;

          Color cor;
          String mensagem;

          if (validade.isBefore(hoje)) {
            cor = Colors.red;
            mensagem = 'VENCIDO';
          } else if (diferenca <= 90) {
            cor = Colors.yellow;
            mensagem = 'Próximo do vencimento: 90 D';
          } else if (diferenca <= 30) {
            cor = Colors.orange;
            mensagem = 'Próximo do vencimento: 30 D';
          } else {
            cor = Colors.green;
            mensagem = 'Dentro da validade';
          }

          final data =
              '${lote.validade.day.toString().padLeft(2, '0')}/'
              '${lote.validade.month.toString().padLeft(2, '0')}/'
              '${lote.validade.year}';
          final unidadeDias = diferenca == 1 ? 'dia' : 'dias';

          return Card(
            child: ListTile(
              onTap: () => _abrirProduto(produto),
              leading: Icon(Icons.warning, color: cor),
              title: Text(
                produto.nome,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Código: ${produto.codigo}\n'
                'Lote: ${lote.numero}\n'
                'Validade: $data ($diferenca $unidadeDias para vencer)\n'
                '$mensagem',
                style: TextStyle(color: cor),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${lote.quantidade} un.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
