import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/agenda/data/models/category_model.dart';
import 'package:bussola/features/agenda/domain/usecases/create_category_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/delete_category_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/get_categories_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/update_category_usecase.dart';

/// Estado das categorias do usuário (padrão + personalizadas).
class CategoryListState {
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? errorMessage;

  const CategoryListState({this.categories = const [], this.isLoading = false, this.errorMessage});

  CategoryListState copyWith({List<CategoryModel>? categories, bool? isLoading, String? errorMessage}) {
    return CategoryListState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  CategoryModel? byId(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// A UI só fala com este Notifier — que só fala com os Use Cases, nunca
/// com o CategoryService/Repository/Data Source diretamente.
class CategoryNotifier extends StateNotifier<CategoryListState> {
  final GetCategoriesUseCase _getCategories;
  final CreateCategoryUseCase _createCategory;
  final UpdateCategoryUseCase _updateCategory;
  final DeleteCategoryUseCase _deleteCategory;

  CategoryNotifier({
    GetCategoriesUseCase? getCategories,
    CreateCategoryUseCase? createCategory,
    UpdateCategoryUseCase? updateCategory,
    DeleteCategoryUseCase? deleteCategory,
  })  : _getCategories = getCategories ?? GetCategoriesUseCase(),
        _createCategory = createCategory ?? CreateCategoryUseCase(),
        _updateCategory = updateCategory ?? UpdateCategoryUseCase(),
        _deleteCategory = deleteCategory ?? DeleteCategoryUseCase(),
        super(const CategoryListState());

  Future<void> load(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final categories = await _getCategories.execute(userId);
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Não foi possível carregar as categorias.');
    }
  }

  Future<bool> createCustom({
    required String userId,
    required String name,
    required String icon,
    required String color,
  }) async {
    try {
      final created = await _createCategory.execute(userId: userId, name: name, icon: icon, color: color);
      state = state.copyWith(categories: [...state.categories, created], errorMessage: null);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Não foi possível criar a categoria.');
      return false;
    }
  }

  Future<bool> update(CategoryModel category, {String? name, String? icon, String? color}) async {
    try {
      final atualizado = await _updateCategory.execute(category, name: name, icon: icon, color: color);
      state = state.copyWith(
        categories: state.categories.map((c) => c.id == atualizado.id ? atualizado : c).toList(),
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Não foi possível atualizar a categoria.');
      return false;
    }
  }

  /// Lança [CategoryInUseException] (não captura) quando há eventos
  /// vinculados e nenhum destino de migração foi passado — a tela decide
  /// o que fazer (perguntar para onde migrar).
  Future<bool> delete(CategoryModel category, {required String userId, String? migrateToCategoryId}) async {
    await _deleteCategory.execute(category, userId: userId, migrateToCategoryId: migrateToCategoryId);
    state = state.copyWith(categories: state.categories.where((c) => c.id != category.id).toList());
    return true;
  }
}

final categoryNotifierProvider = StateNotifierProvider<CategoryNotifier, CategoryListState>(
  (ref) => CategoryNotifier(),
);
