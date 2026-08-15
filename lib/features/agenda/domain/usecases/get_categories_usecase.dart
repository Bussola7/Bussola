import 'package:bussola/features/agenda/data/models/category_model.dart';
import 'package:bussola/features/agenda/domain/services/category_service.dart';

class GetCategoriesUseCase {
  final CategoryService _service;

  GetCategoriesUseCase({CategoryService? service}) : _service = service ?? CategoryService();

  Future<List<CategoryModel>> execute(String userId) => _service.listCategories(userId);
}
