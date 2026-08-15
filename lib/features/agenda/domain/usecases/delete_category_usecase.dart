import 'package:bussola/features/agenda/data/models/category_model.dart';
import 'package:bussola/features/agenda/domain/services/category_service.dart';

/// Reexporta o erro do Service para a presentation não precisar importar
/// a camada de domain diretamente de dois lugares diferentes.
export 'package:bussola/features/agenda/domain/services/category_service.dart' show CategoryInUseException;

class DeleteCategoryUseCase {
  final CategoryService _service;

  DeleteCategoryUseCase({CategoryService? service}) : _service = service ?? CategoryService();

  /// Lança [CategoryInUseException] se houver eventos vinculados e
  /// [migrateToCategoryId] não for informado — a UI deve capturar esse
  /// erro e perguntar para onde migrar antes de chamar de novo.
  Future<void> execute(
    CategoryModel category, {
    required String userId,
    String? migrateToCategoryId,
  }) {
    return _service.deleteCategory(category, userId: userId, migrateToCategoryId: migrateToCategoryId);
  }
}
