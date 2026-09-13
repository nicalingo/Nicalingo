class SignupFlowModel {
  final String email;
  final String? nickname;
  final String? avatarUrl;
  final String? languageId;
  final String? password;

  SignupFlowModel({
    required this.email,
    this.nickname,
    this.avatarUrl,
    this.languageId,
    this.password,
  });

  SignupFlowModel copyWith({
    String? email,
    String? nickname,
    String? avatarUrl,
    String? languageId,
    String? password,
  }) {
    return SignupFlowModel(
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      languageId: languageId ?? this.languageId,
      password: password ?? this.password,
    );
  }
}