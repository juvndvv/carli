abstract final class HabitsPaths {
  static const root = '/habitos';
  static const today = '/habitos/hoy';
  static const list = '/habitos/lista';
  static const progress = '/habitos/progreso';
  static const create = '/habitos/nuevo';
  static const settings = '/habitos/ajustes';

  static String habit(String id) => '/habitos/habito/$id';
  static String edit(String id) => '/habitos/habito/$id/editar';

  static bool owns(String location) => location == root || location.startsWith('$root/');
}
