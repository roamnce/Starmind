class ExportException implements Exception {
  const ExportException(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() => details == null ? 'ExportException: $message' : 'ExportException: $message ($details)';
}
