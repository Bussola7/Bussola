import 'package:bussola/features/agenda/data/models/category_model.dart';
import 'package:bussola/features/agenda/data/repositories/category_repository.dart';
import 'package:bussola/features/agenda/data/repositories/event_repository.dart';

/// Erro específico: a categoria tem eventos vinculados e nenhum destino
/// de migração foi informado. A UI captura este erro para então perguntar
/// ao usuário para onde migrar os eventos (ou cancelar).
class CategoryInUseException implements Exception {
  final int quantidadeEventos;
  const CategoryInUseException(this.quantidadeEventos);
}

/// Regras de negócio de categorias: nome obrigatório e não duplicado,
/// categoria padrão nunca pode ser excluída, e uma categoria personalizada
/// só pode ser excluída se não tiver eventos vinculados — ou se o chamador
/// informar para qual categoria migrar esses eventos primeiro.
class CategoryService {
  final CategoryRepository _repository;
  final EventRepository _eventRepository;

  CategoryService({CategoryRepository? repository, EventRepository? eventRepository})
      : _repository = repository ?? CategoryRepository(),
        _eventRepository = eventRepository ?? EventRepository();

  Future<List<CategoryModel>> listCategories(String userId) => _repository.getAll(userId);

  Future<CategoryModel> createCustomCategory({
    required String userId,
    required String name,
    required String icon,
    required String color,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('O nome da categoria não pode ser vazio.');
    }

    final existentes = await _repository.getAll(userId);
    final jaExiste = existentes.any((c) => c.name.trim().toLowerCase() == name.trim().toLowerCase());
    if (jaExiste) {
      throw StateError('Já existe uma categoria com esse nome.');
    }

    final now = DateTime.now();
    return _repository.create(CategoryModel(
      id: '',
      userId: userId,
      name: name.trim(),
      icon: icon,
      color: color,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    ));
  }

  /// Editar uma categoria (nome/ícone/cor). Como o `EventCard`/`EventDetail`
  /// sempre buscam a categoria pelo `categoryId` — nunca guardam uma cópia —
  /// a mudança aparece automaticamente em todos os eventos vinculados, sem
  /// precisar tocar em nenhum evento.
  Future<CategoryModel> updateCategory(CategoryModel category, {String? name, String? icon, String? color}) {
    if (category.isDefault) {
      throw StateError('Categorias padrão não podem ser editadas.');
    }
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError('O nome da categoria não pode ser vazio.');
    }
    return _repository.update(category.id, {
      if (name != null) 'name': name.trim(),
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    });
  }

  /// Categorias padrão nunca podem ser excluídas. Categorias personalizadas
  /// só podem ser excluídas direto se não houver eventos vinculados; caso
  /// contrário, é preciso informar [migrateToCategoryId] — a chamada sem
  /// esse parâmetro lança [CategoryInUseException] para a UI perguntar ao
  /// usuário para onde migrar antes.
  Future<void> deleteCategory(
    CategoryModel category, {
    required String userId,
    String? migrateToCategoryId,
  }) async {
    if (category.isDefault) {
      throw StateError('Categorias padrão não podem ser excluídas.');
    }

    final quantidade = await _eventRepository.countByCategory(userId: userId, categoryId: category.id);

    if (quantidade > 0) {
      if (migrateToCategoryId == null) {
        throw CategoryInUseException(quantidade);
      }
      await _eventRepository.reassignCategory(
        userId: userId,
        fromCategoryId: category.id,
        toCategoryId: migrateToCategoryId,
      );
    }

    await _repository.delete(category.id);
  }
}
