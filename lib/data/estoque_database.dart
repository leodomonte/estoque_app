import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/lote.dart';
import '../models/prateleira.dart';
import '../models/produto.dart';

class EstoqueDatabase {
  EstoqueDatabase._();

  static const int prateleiraGeralId = 1;
  static final EstoqueDatabase instance = EstoqueDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = p.join(await getDatabasesPath(), 'estoque_app.db');
    await _copiarBancoInicialSeNecessario(path);
    _database = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE prateleiras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL COLLATE NOCASE UNIQUE
          )
        ''');
        await db.insert('prateleiras', {'id': 1, 'nome': 'Prateleira geral'});
        await db.execute('''
          CREATE TABLE produtos (
            codigo TEXT PRIMARY KEY,
            nome TEXT NOT NULL,
            prateleira_id INTEGER NOT NULL,
            FOREIGN KEY (prateleira_id) REFERENCES prateleiras (id)
          )
        ''');
        await _criarTabelaLotes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE prateleiras (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nome TEXT NOT NULL COLLATE NOCASE UNIQUE
            )
          ''');
          await db.insert('prateleiras', {'id': 1, 'nome': 'Prateleira geral'});
          await db.execute('''
            ALTER TABLE produtos ADD COLUMN prateleira_id INTEGER
              REFERENCES prateleiras (id)
          ''');
          await db.update('produtos', {'prateleira_id': 1});
        }
        if (oldVersion < 3) {
          // O catálogo completo foi importado para a Prateleira geral,
          // deixando a abertura lenta. Removemos esses produtos uma única
          // vez nesta migração, preservando as demais prateleiras.
          await db.delete(
            'lotes',
            where: 'produto_codigo IN (SELECT codigo FROM produtos WHERE prateleira_id = ?)',
            whereArgs: [prateleiraGeralId],
          );
          await db.delete(
            'produtos',
            where: 'prateleira_id = ?',
            whereArgs: [prateleiraGeralId],
          );
        }
        if (oldVersion < 4) {
          // Limpa os produtos da Prateleira geral na migração existente.
          await db.delete(
            'lotes',
            where: 'produto_codigo IN (SELECT codigo FROM produtos WHERE prateleira_id = ?)',
            whereArgs: [prateleiraGeralId],
          );
          await db.delete(
            'produtos',
            where: 'prateleira_id = ?',
            whereArgs: [prateleiraGeralId],
          );
        }
      },
    );
    return _database!;
  }

  Future<void> _copiarBancoInicialSeNecessario(String caminho) async {
    final arquivo = File(caminho);
    if (await arquivo.exists()) return;

    await arquivo.parent.create(recursive: true);
    final dados = await rootBundle.load('assets/database/estoque_app_BD.db');
    final temporario = File('$caminho.initial');
    await temporario.writeAsBytes(
      dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes),
      flush: true,
    );
    await temporario.rename(caminho);
  }

  static Future<void> _criarTabelaLotes(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE lotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produto_codigo TEXT NOT NULL,
        numero TEXT NOT NULL,
        validade TEXT NOT NULL,
        quantidade INTEGER NOT NULL,
        FOREIGN KEY (produto_codigo) REFERENCES produtos (codigo)
          ON DELETE CASCADE,
        UNIQUE (produto_codigo, numero)
      )
    ''');
  }

  Future<List<Prateleira>> carregarPrateleiras() async {
    final db = await database;
    final rows = await db.query('prateleiras', orderBy: 'nome COLLATE NOCASE');
    return rows
        .map(
          (row) =>
              Prateleira(id: row['id'] as int, nome: row['nome'] as String),
        )
        .toList();
  }

  Future<int> criarPrateleira(String nome) async {
    final db = await database;
    return db.insert('prateleiras', {'nome': nome.trim()});
  }

  Future<int> excluirPrateleira(int id) async {
    if (id == prateleiraGeralId) {
      throw StateError('A Prateleira geral não pode ser excluída.');
    }
    final db = await database;
    return db.transaction((txn) async {
      final total =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM produtos WHERE prateleira_id = ?',
              [id],
            ),
          ) ??
          0;
      if (total > 0) {
        await txn.update(
          'produtos',
          {'prateleira_id': prateleiraGeralId},
          where: 'prateleira_id = ?',
          whereArgs: [id],
        );
      }
      await txn.delete('prateleiras', where: 'id = ?', whereArgs: [id]);
      return total;
    });
  }

  Future<List<Produto>> carregarProdutos() async {
    final db = await database;
    final rows = await db.query('produtos', orderBy: 'nome COLLATE NOCASE');
    final lotesRows = await db.query('lotes', orderBy: 'validade');
    final lotesPorProduto = <String, List<Lote>>{};
    for (final loteRow in lotesRows) {
      final codigo = loteRow['produto_codigo'] as String;
      lotesPorProduto
          .putIfAbsent(codigo, () => [])
          .add(
            Lote(
              numero: loteRow['numero'] as String,
              validade: DateTime.parse(loteRow['validade'] as String),
              quantidade: loteRow['quantidade'] as int,
            ),
          );
    }

    final produtos = <Produto>[];
    for (final row in rows) {
      final codigo = row['codigo'] as String;
      produtos.add(
        Produto(
          codigo: codigo,
          nome: row['nome'] as String,
          prateleiraId: row['prateleira_id'] as int,
          lotes: lotesPorProduto[codigo] ?? [],
        ),
      );
    }
    return produtos;
  }

  Future<void> salvarProdutoComLote(Produto produto, Lote lote) async {
    final db = await database;
    await db.transaction((txn) async {
      final existente = await txn.query(
        'produtos',
        columns: ['prateleira_id'],
        where: 'codigo = ?',
        whereArgs: [produto.codigo],
      );
      if (existente.isNotEmpty &&
          existente.first['prateleira_id'] != produto.prateleiraId) {
        throw StateError('Este produto já está em outra prateleira.');
      }
      await txn.insert('produtos', {
        'codigo': produto.codigo,
        'nome': produto.nome,
        'prateleira_id': produto.prateleiraId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('lotes', {
        'produto_codigo': produto.codigo,
        'numero': lote.numero,
        'validade': lote.validade.toIso8601String(),
        'quantidade': lote.quantidade,
      });
    });
  }

  Future<void> atualizarProduto({
    required String codigoAntigo,
    required String novoCodigo,
    required String nome,
    required int prateleiraId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (codigoAntigo != novoCodigo) {
        final codigoEmUso = await txn.query(
          'produtos',
          columns: ['codigo'],
          where: 'codigo = ?',
          whereArgs: [novoCodigo],
        );
        if (codigoEmUso.isNotEmpty) {
          throw StateError('Já existe um produto com esse código.');
        }

        await txn.insert('produtos', {
          'codigo': novoCodigo,
          'nome': nome,
          'prateleira_id': prateleiraId,
        });
        await txn.update(
          'lotes',
          {'produto_codigo': novoCodigo},
          where: 'produto_codigo = ?',
          whereArgs: [codigoAntigo],
        );
        await txn.delete(
          'produtos',
          where: 'codigo = ?',
          whereArgs: [codigoAntigo],
        );
      } else {
        await txn.update(
          'produtos',
          {'nome': nome, 'prateleira_id': prateleiraId},
          where: 'codigo = ?',
          whereArgs: [codigoAntigo],
        );
      }
    });
  }

  Future<void> atualizarQuantidade(Produto produto, Lote lote) async {
    final db = await database;
    final alterados = await db.update(
      'lotes',
      {'quantidade': lote.quantidade},
      where: 'produto_codigo = ? AND numero = ?',
      whereArgs: [produto.codigo, lote.numero],
    );
    if (alterados == 0) {
      throw StateError('O lote não foi encontrado no banco de dados.');
    }
  }

  Future<void> excluirProduto(String codigo) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'lotes',
        where: 'produto_codigo = ?',
        whereArgs: [codigo],
      );
      await txn.delete('produtos', where: 'codigo = ?', whereArgs: [codigo]);
    });
  }

  Future<void> excluirLote(Produto produto, Lote lote) async {
    final db = await database;
    final removidos = await db.delete(
      'lotes',
      where: 'produto_codigo = ? AND numero = ?',
      whereArgs: [produto.codigo, lote.numero],
    );
    if (removidos == 0) {
      throw StateError('O lote não foi encontrado no banco de dados.');
    }
  }
}
