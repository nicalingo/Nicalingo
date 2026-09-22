class SignupFlowModel {
  final String email;
  final String? fullName; // <-- Nombre completo agregado
  final String? nickname;
  final String? avatarUrl;
  final String? languageId;
  final String? password;

  SignupFlowModel({
    required this.email,
    this.fullName,
    this.nickname,
    this.avatarUrl,
    this.languageId,
    this.password,
  });

  SignupFlowModel copyWith({
    String? email,
    String? fullName,
    String? nickname,
    String? avatarUrl,
    String? languageId,
    String? password,
  }) {
    return SignupFlowModel(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      languageId: languageId ?? this.languageId,
      password: password ?? this.password,
    );
  }
}