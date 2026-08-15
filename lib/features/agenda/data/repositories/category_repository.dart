import 'package:bussola/features/agenda/data/datasources/category_datasource.dart';
import 'package:bussola/features/agenda/data/models/category_model.dart';

/// Converte entre JSON cru (do datasource) e [CategoryModel].
class CategoryRepository {
  final CategoryDataSource _dataSource;

  CategoryRepository({CategoryDataSource? dataSource}) : _dataSource = dataSource ?? CategoryDataSource();

  Future<List<CategoryModel>> getAll(String userId) async {
    final rows = await _dataSource.fetchAll(userId);
    return rows.map(CategoryModel.fromJson).toList();
  }

  Future<CategoryModel> create(CategoryModel category) async {
    final row = await _dataSource.insert(category.toInsertJson(userId: category.userId));
    return CategoryModel.fromJson(row);
  }

  Future<CategoryModel> update(String id, Map<String, dynamic> changes) async {
    final row = await _dataSource.update(id, changes);
    return CategoryModel.fromJson(row);
  }

  Future<void> delete(String id) => _dataSource.delete(id);
}
