abstract final class TasksRoutes {
  static const root = '/tareas';
  static const today = '/tareas/hoy';
  static const upcoming = '/tareas/proximas';
  static const lists = '/tareas/listas';
  static const templates = '/tareas/plantillas';
  static const newTemplate = '/tareas/plantillas/nueva';
  static const settings = '/tareas/ajustes';

  static String task(String id) => '/tareas/tarea/$id';
  static String list(String id) => '$lists/$id';
  static String template(String id) => '$templates/$id';
}
