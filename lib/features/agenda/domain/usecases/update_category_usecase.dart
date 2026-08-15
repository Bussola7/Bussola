import 'package:bussola/features/agenda/data/models/category_model.dart';
import 'package:bussola/features/agenda/domain/services/category_service.dart';

class UpdateCategoryUseCase {
  final CategoryService _service;

  UpdateCategoryUseCase({CategoryService? service}) : _service = service ?? CategoryService();

  Future<CategoryModel> execute(CategoryModel category, {String? name, String? icon, String? color}) {
    return _service.updateCategory(category, name: name, icon: icon, color: color);
  }
}
