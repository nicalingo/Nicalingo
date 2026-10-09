class SignupFlowModel {
  final String email;
  final String? name;
  final String? apellidos;
  final String? departamento;
  final int? edad;
  final String? sexo;
  final String? nickname;
  final String? avatarUrl;
  final String? languageId;
  final String? password;

  SignupFlowModel({
    required this.email,
    this.name,
    this.apellidos,
    this.departamento,
    this.edad,
    this.sexo,
    this.nickname,
    this.avatarUrl,
    this.languageId,
    this.password,
  });

  SignupFlowModel copyWith({
    String? email,
    String? name,
    String? apellidos,
    String? departamento,
    int? edad,
    String? sexo,
    String? nickname,
    String? avatarUrl,
    String? languageId,
    String? password,
  }) {
    return SignupFlowModel(
      email: email ?? this.email,
      name: name ?? this.name,
      apellidos: apellidos ?? this.apellidos,
      departamento: departamento ?? this.departamento,
      edad: edad ?? this.edad,
      sexo: sexo ?? this.sexo,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      languageId: languageId ?? this.languageId,
      password: password ?? this.password,
    );
  }
}