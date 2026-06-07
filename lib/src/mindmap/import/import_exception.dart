class ImportException implements Exception {
  const ImportException(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() => details == null ? 'ImportException: $message' : 'ImportException: $message ($details)';
}
