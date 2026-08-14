/// A transport/HTTP failure translated into something the UI can show a human.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode, this.fieldErrors});

  final String message;
  final String? code;
  final int? statusCode;

  /// field name -> message, so forms can highlight the offending input
  final Map<String, String>? fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}
