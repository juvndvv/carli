class CurrentUser {
  const CurrentUser({required this.id, required this.name, required this.email});

  factory CurrentUser.fromJson(Map<String, dynamic> json) =>
      CurrentUser(id: json['id'] as String, name: json['name'] as String, email: json['email'] as String);

  final String id;
  final String name;
  final String email;
}
