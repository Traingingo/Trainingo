class UserModel {
  final int id;
  final String email;
  final String nickname;

  UserModel({
    required this.id,
    required this.email,
    required this.nickname,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      email: json['email']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
    };
  }
}
