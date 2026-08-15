import 'package:bussola/features/agenda/data/datasources/calendar_datasource.dart';
import 'package:bussola/features/agenda/data/models/calendar_model.dart';

/// Converte entre JSON cru (do datasource) e [CalendarModel].
/// Não contém regra de negócio — só tradução de dados.
class CalendarRepository {
  final CalendarDataSource _dataSource;

  CalendarRepository({CalendarDataSource? dataSource}) : _dataSource = dataSource ?? CalendarDataSource();

  Future<List<CalendarModel>> getAll(String userId) async {
    final rows = await _dataSource.fetchAll(userId);
    return rows.map(CalendarModel.fromJson).toList();
  }

  Future<CalendarModel> create(CalendarModel calendar) async {
    final row = await _dataSource.insert(calendar.toInsertJson(userId: calendar.userId));
    return CalendarModel.fromJson(row);
  }

  Future<CalendarModel> update(String id, Map<String, dynamic> changes) async {
    final row = await _dataSource.update(id, changes);
    return CalendarModel.fromJson(row);
  }

  Future<void> delete(String id) => _dataSource.delete(id);
}
