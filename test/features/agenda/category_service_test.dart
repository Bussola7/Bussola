import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/category_model.dart';
import 'package:bussola/features/agenda/data/repositories/category_repository.dart';
import 'package:bussola/features/agenda/data/repositories/event_repository.dart';
import 'package:bussola/features/agenda/domain/services/category_service.dart';

CategoryModel _buildCategory({required String name, bool isDefault = false, String id = 'cat-1'}) {
  final now = DateTime.now();
  return CategoryModel(
    id: id,
    userId: 'user-1',
    name: name,
    icon: 'label',
    color: '#64748B',
    isDefault: isDefault,
    createdAt: now,
    updatedAt: now,
  );
}

/// Repositório falso com uma lista fixa de categorias já existentes,
/// usado para testar a regra de "nome duplicado" sem tocar no Supabase.
class _FakeCategoryRepository extends CategoryRepository {
  final List<CategoryModel> existentes;
  final List<CategoryModel> excluidas = [];
  Map<String, dynamic>? lastUpdateChanges;

  _FakeCategoryRepository(this.existentes);

  @override
  Future<List<CategoryModel>> getAll(String userId) async => existentes;

  @override
  Future<CategoryModel> create(CategoryModel category) async => category;

  @override
  Future<CategoryModel> update(String id, Map<String, dynamic> changes) async {
    lastUpdateChanges = changes;
    final atual = existentes.firstWhere((c) => c.id == id);
    return atual.copyWith(
      name: changes['name'] as String?,
      icon: changes['icon'] as String?,
      color: changes['color'] as String?,
    );
  }

  @override
  Future<void> delete(String id) async {
    excluidas.add(existentes.firstWhere((c) => c.id == id));
  }
}

/// EventRepository falso: permite configurar quantos eventos "existem"
/// para uma categoria, e registra se a reatribuição foi chamada.
class _FakeEventRepository extends EventRepository {
  final int quantidadeEventosNaCategoria;
  bool reassignChamado = false;
  String? reassignFrom;
  String? reassignTo;

  _FakeEventRepository({this.quantidadeEventosNaCategoria = 0});

  @override
  Future<int> countByCategory({required String userId, required String categoryId}) async {
    return quantidadeEventosNaCategoria;
  }

  @override
  Future<void> reassignCategory({required String userId, required String fromCategoryId, required String toCategoryId}) async {
    reassignChamado = true;
    reassignFrom = fromCategoryId;
    reassignTo = toCategoryId;
  }
}

void main() {
  group('CategoryService.createCustomCategory', () {
    test('cria categoria personalizada com nome novo', () async {
      final repo = _FakeCategoryRepository([_buildCategory(name: 'Trabalho', isDefault: true)]);
      final service = CategoryService(repository: repo, eventRepository: _FakeEventRepository());

      final created = await service.createCustomCategory(
        userId: 'user-1',
        name: 'Projetos pessoais',
        icon: 'star',
        color: '#A855F7',
      );

      expect(created.name, 'Projetos pessoais');
      expect(created.isDefault, false);
    });

    test('rejeita nome de categoria duplicado (sem diferenciar maiúsculas)', () async {
      final repo = _FakeCategoryRepository([_buildCategory(name: 'Trabalho', isDefault: true)]);
      final service = CategoryService(repository: repo, eventRepository: _FakeEventRepository());

      expect(
        () => service.createCustomCategory(userId: 'user-1', name: 'trabalho', icon: 'briefcase', color: '#2563EB'),
        throwsStateError,
      );
    });

    test('rejeita nome vazio', () async {
      final repo = _FakeCategoryRepository([]);
      final service = CategoryService(repository: repo, eventRepository: _FakeEventRepository());

      expect(
        () => service.createCustomCategory(userId: 'user-1', name: '   ', icon: 'star', color: '#000000'),
        throwsArgumentError,
      );
    });
  });

  group('CategoryService.updateCategory', () {
    test('atualiza nome/ícone/cor de categoria personalizada', () async {
      final custom = _buildCategory(name: 'Projetos pessoais');
      final repo = _FakeCategoryRepository([custom]);
      final service = CategoryService(repository: repo, eventRepository: _FakeEventRepository());

      final atualizado = await service.updateCategory(custom, name: 'Projetos', color: '#000000');

      expect(atualizado.name, 'Projetos');
      expect(repo.lastUpdateChanges?['name'], 'Projetos');
    });

    test('impede edição de categoria padrão', () async {
      final padrao = _buildCategory(name: 'Trabalho', isDefault: true);
      final repo = _FakeCategoryRepository([padrao]);
      final service = CategoryService(repository: repo, eventRepository: _FakeEventRepository());

      expect(() => service.updateCategory(padrao, name: 'Trampo'), throwsStateError);
    });
  });

  group('CategoryService.deleteCategory', () {
    test('impede exclusão de categoria padrão', () async {
      final defaultCategory = _buildCategory(name: 'Trabalho', isDefault: true);
      final repo = _FakeCategoryRepository([defaultCategory]);
      final service = CategoryService(repository: repo, eventRepository: _FakeEventRepository());

      expect(() => service.deleteCategory(defaultCategory, userId: 'user-1'), throwsStateError);
    });

    test('permite exclusão de categoria personalizada sem eventos vinculados', () async {
      final custom = _buildCategory(name: 'Projetos pessoais');
      final repo = _FakeCategoryRepository([custom]);
      final service = CategoryService(repository: repo, eventRepository: _FakeEventRepository(quantidadeEventosNaCategoria: 0));

      await service.deleteCategory(custom, userId: 'user-1');

      expect(repo.excluidas, contains(custom));
    });

    test('REGRA DE NEGÓCIO: lança CategoryInUseException quando há eventos e nenhuma migração foi informada', () async {
      final custom = _buildCategory(name: 'Projetos pessoais');
      final repo = _FakeCategoryRepository([custom]);
      final service = CategoryService(repository: repo, eventRepository: _FakeEventRepository(quantidadeEventosNaCategoria: 3));

      expect(
        () => service.deleteCategory(custom, userId: 'user-1'),
        throwsA(isA<CategoryInUseException>()),
      );
      expect(repo.excluidas, isEmpty); // não excluiu nada até confirmar a migração
    });

    test('migra os eventos e depois exclui, quando migrateToCategoryId é informado', () async {
      final custom = _buildCategory(name: 'Projetos pessoais', id: 'cat-antiga');
      final repo = _FakeCategoryRepository([custom]);
      final fakeEventRepo = _FakeEventRepository(quantidadeEventosNaCategoria: 3);
      final service = CategoryService(repository: repo, eventRepository: fakeEventRepo);

      await service.deleteCategory(custom, userId: 'user-1', migrateToCategoryId: 'cat-nova');

      expect(fakeEventRepo.reassignChamado, true);
      expect(fakeEventRepo.reassignFrom, 'cat-antiga');
      expect(fakeEventRepo.reassignTo, 'cat-nova');
      expect(repo.excluidas, contains(custom));
    });
  });
}
