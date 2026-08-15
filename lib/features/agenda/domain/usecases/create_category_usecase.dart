import 'package:bussola/features/agenda/data/models/category_model.dart';
import 'package:bussola/features/agenda/domain/services/category_service.dart';

class CreateCategoryUseCase {
  final CategoryService _service;

  CreateCategoryUseCase({CategoryService? service}) : _service = service ?? CategoryService();

  Future<CategoryModel> execute({
    required String userId,
    required String name,
    required String icon,
    required String color,
  }) {
    return _service.createCustomCategory(userId: userId, name: name, icon: icon, color: color);
  }
}
