import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? fullName;
  final String email;
  final String role;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    this.fullName,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
  });

  @override
  // TODO: implement props
  List<Object?> get props => [id, fullName, email, role, avatarUrl, createdAt];
}
