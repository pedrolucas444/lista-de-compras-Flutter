import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:glassy_navbar/glassy_navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista de Compras',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PaginaInicial(),
    );
  }
}

class Item {
  String nome;
  String categoria;
  bool comprado;

  Item({required this.nome, this.categoria = 'Outros', this.comprado = false});

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'categoria': categoria,
        'comprado': comprado,
      };

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        nome: json['nome'] as String,
        categoria: json['categoria'] as String? ?? 'Outros',
        comprado: json['comprado'] as bool? ?? false,
      );
}

class PaginaInicial extends StatefulWidget {
  const PaginaInicial({super.key});

  @override
  State<PaginaInicial> createState() => _PaginaInicialState();
}

class _PaginaInicialState extends State<PaginaInicial> with SingleTickerProviderStateMixin {
  int _indiceAtual = 0;
  final List<Item> _itens = [];
  final TextEditingController _controladorTexto = TextEditingController();
  final TextEditingController _controladorBusca = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  String _filtroCategoria = 'Todas';
  bool _mostrarComprados = true;
  List<String> categorias = ['Todas', 'Supermercado', 'Hortifruti', 'Padaria', 'Bebidas', 'Outros'];

  @override
  void initState() {
    super.initState();
    _carregarItens();
  }

  Future<void> _carregarItens() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('lista_itens');
    if (jsonString != null) {
      final List<dynamic> dados = jsonDecode(jsonString) as List<dynamic>;
      setState(() {
        _itens.clear();
        _itens.addAll(dados.map((e) => Item.fromJson(e as Map<String, dynamic>)));
      });
    }
  }

  Future<void> _salvarItens() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_itens.map((i) => i.toJson()).toList());
    await prefs.setString('lista_itens', jsonString);
  }

  void _adicionarItem({String? nome, String? categoria}) {
    final texto = (nome ?? _controladorTexto.text).trim();
    final cat = categoria ?? (categorias.contains(_filtroCategoria) && _filtroCategoria != 'Todas' ? _filtroCategoria : 'Outros');
    if (texto.isEmpty) return;

    // evitar duplicatas exatas
    if (_itens.any((it) => it.nome.toLowerCase() == texto.toLowerCase())) {
      _mostrarMensagem('Este item já existe');
      return;
    }

    final novo = Item(nome: texto, categoria: cat, comprado: false);
    setState(() {
      _itens.insert(0, novo);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
      _controladorTexto.clear();
    });
    _salvarItens();
    _mostrarMensagem('Item "${novo.nome}" adicionado');
  }

  void _removerItem(int index) {
    final Item removido = _itens.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: _buildTile(removido, index, animation),
      ),
      duration: const Duration(milliseconds: 350),
    );
    _salvarItens();
    _mostrarMensagem('Item "${removido.nome}" removido');
  }

  void _marcarComoComprado(int index, bool comprado) {
    setState(() {
      _itens[index].comprado = comprado;
    });
    _salvarItens();
    _mostrarMensagem(comprado ? 'Item marcado como comprado' : 'Item desmarcado');
  }

  void _limparLista() {
    if (_itens.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar lista'),
        content: const Text('Deseja realmente remover todos os itens?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final len = _itens.length;
              setState(() {
                _itens.clear();
              });
              for (var i = len - 1; i >= 0; i--) {
                _listKey.currentState?.removeItem(
                  i,
                  (context, animation) => const SizedBox.shrink(),
                );
              }
              _salvarItens();
              Navigator.pop(context);
            },
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Item> get _itensFiltrados {
    final query = _controladorBusca.text.trim().toLowerCase();
    return _itens.where((it) {
      if (!_mostrarComprados && it.comprado) return false;
      if (_filtroCategoria != 'Todas' && it.categoria != _filtroCategoria) return false;
      if (query.isNotEmpty && !it.nome.toLowerCase().contains(query)) return false;
      return true;
    }).toList();
  }

  Widget _buildTile(Item item, int index, Animation<double> animation) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: item.comprado,
          onChanged: (v) => _marcarComoComprado(index, v ?? false),
        ),
        title: Text(
          item.nome,
          style: TextStyle(
            decoration: item.comprado ? TextDecoration.lineThrough : null,
            color: item.comprado ? Colors.grey : Colors.black,
            fontSize: 16,
          ),
        ),
        subtitle: Text(item.categoria),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => Share.share('Comprar: ${item.nome} (${item.categoria})'),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _mostrarConfirmacaoRemocao(index),
            ),
          ],
        ),
        tileColor: item.comprado ? Colors.green[50] : null,
      ),
    );
  }

  void _mostrarConfirmacaoRemocao(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover item'),
        content: Text('Remover "${_itens[index].nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removerItem(index);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), duration: const Duration(seconds: 2)));
  }

  void _compartilharLista() {
    if (_itens.isEmpty) {
      _mostrarMensagem('Lista vazia');
      return;
    }
    final buffer = StringBuffer();
    for (final it in _itens) {
      buffer.writeln('- ${it.nome} [${it.categoria}] ${it.comprado ? "(✔)" : ""}');
    }
    Share.share('Minha lista de compras:\n\n${buffer.toString()}');
  }

  // Estatística pequena
  Widget _criarEstatistica(String titulo, String valor, IconData icone, Color cor) {
    return Column(
      children: [
        Icon(icone, color: cor, size: 24),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor),
        ),
        Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _mostrarAdicionarComCategoria() {
    String nome = '';
    String categoria = categorias.firstWhere((c) => c != 'Todas', orElse: () => 'Outros');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Nome'),
              onChanged: (v) => nome = v,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: categoria,
              items: categorias.where((c) => c != 'Todas').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => categoria = v ?? 'Outros',
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (nome.trim().isEmpty) return;
              Navigator.pop(context);
              _adicionarItem(nome: nome.trim(), categoria: categoria);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controladorTexto.dispose();
    _controladorBusca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Minha Lista de Compras'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _limparLista, tooltip: 'Limpar lista'),
          IconButton(icon: const Icon(Icons.share), onPressed: _compartilharLista, tooltip: 'Compartilhar lista'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controladorTexto,
                    decoration: const InputDecoration(
                      hintText: 'Digite um item para comprar...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_shopping_cart),
                    ),
                    onSubmitted: (_) => _adicionarItem(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _mostrarAdicionarComCategoria,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
          ),

          // busca e filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controladorBusca,
                    decoration: const InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filtroCategoria,
                  items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _filtroCategoria = v ?? 'Todas'),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Text('Mostrar comprados'),
                    Switch(value: _mostrarComprados, onChanged: (v) => setState(() => _mostrarComprados = v)),
                  ],
                ),
              ],
            ),
          ),

          // estatísticas
          if (_itens.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _criarEstatistica('Total', '${_itens.length}', Icons.list, Colors.blue),
                  _criarEstatistica('Comprados', '${_itens.where((i) => i.comprado).length}', Icons.check_circle, Colors.green),
                  _criarEstatistica('Restantes', '${_itens.where((i) => !i.comprado).length}', Icons.pending, Colors.orange),
                ],
              ),
            ),

          // lista animada
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _itensFiltrados.isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('Sua lista está vazia!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const Text('Adicione itens para começar suas compras', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  : AnimatedList(
                      key: _listKey,
                      initialItemCount: _itens.length,
                      itemBuilder: (context, index, animation) {
                        final item = _itens[index];
                        // show only filtered items visually; keep indexes aligned with real list for actions
                        if (!_itensFiltrados.contains(item)) {
                          return const SizedBox.shrink();
                        }
                        return SizeTransition(
                          sizeFactor: animation,
                          child: _buildTile(item, index, animation),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlassyNavBar(
        currentIndex: _indiceAtual,
        onItemTap: (index) {
          setState(() {
            _indiceAtual = index;
          });
        },
  backgroundColor: Colors.blue.withAlpha(51),
        items: const [
          GlassyNavBarItem(icon: Icons.shopping_cart, label: 'Lista'),
          GlassyNavBarItem(icon: Icons.home, label: 'Home'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarAdicionarComCategoria,
        child: const Icon(Icons.add),
      ),
    );
  }
}