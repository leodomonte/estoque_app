import 'lote.dart';

class Produto {
  String codigo;
  String nome;
  int prateleiraId;
  final List<Lote> lotes;

  Produto({
    required this.codigo,
    required this.nome,
    required this.prateleiraId,
    required this.lotes,
  });
}
