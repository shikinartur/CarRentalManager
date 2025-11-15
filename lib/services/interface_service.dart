import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth/role_selection_screen.dart';

/// Сервис для управления выбранным типом интерфейса
class InterfaceService {
  static const String _interfaceTypeKey = 'selected_interface_type';
  
  /// Сохранить выбранный тип интерфейса
  Future<void> saveInterfaceType(InterfaceType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_interfaceTypeKey, type.name);
  }
  
  /// Получить сохраненный тип интерфейса
  Future<InterfaceType?> getInterfaceType() async {
    final prefs = await SharedPreferences.getInstance();
    final typeName = prefs.getString(_interfaceTypeKey);
    
    if (typeName == null) return null;
    
    return InterfaceType.values.firstWhere(
      (type) => type.name == typeName,
      orElse: () => InterfaceType.rental,
    );
  }
  
  /// Очистить сохраненный тип интерфейса (при выходе)
  Future<void> clearInterfaceType() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_interfaceTypeKey);
  }
}
