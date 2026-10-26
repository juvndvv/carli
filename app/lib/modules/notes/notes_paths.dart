abstract final class NotesPaths {
  static const root = '/notas';
  static const shopping = '/compra';
  static const archived = '/notas/archivadas';
  static const trash = '/notas/papelera';
  static const settings = '/notas/ajustes';

  static String note(String id, {bool fresh = false}) => '/notas/n/$id${fresh ? '?nueva=1' : ''}';
  static String folder(String id) => '/notas/carpeta/$id';

  static bool coversShellBar(String location) => location.startsWith('$root/n/');

  static bool owns(String location) =>
      location == root || location.startsWith('$root/') || location == shopping || location.startsWith('$shopping/');
}
