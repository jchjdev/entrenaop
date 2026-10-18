import 'dart:typed_data';

class ProgramCover {
  const ProgramCover({
    required this.programId,
    this.cardPath,
    this.headerPath,
    this.cardUrl,
    this.headerUrl,
    this.focalX = 0.5,
    this.focalY = 0.5,
    double? headerFocalX,
    double? headerFocalY,
    this.revision = 0,
  }) : headerFocalX = headerFocalX ?? focalX,
       headerFocalY = headerFocalY ?? focalY;
  final String programId;
  final String? cardPath, headerPath, cardUrl, headerUrl;
  final double focalX, focalY;
  final double headerFocalX, headerFocalY;
  final int revision;
  bool get hasImage => cardPath != null;
}

class ProgramCoverUpload {
  const ProgramCoverUpload({required this.card, required this.header});
  final Uint8List card, header;
}

class ProgramCoverConflict implements Exception {
  const ProgramCoverConflict();
}

abstract class ProgramCoverRepository {
  Future<ProgramCover> load(String programId);
  Future<ProgramCover> save(
    ProgramCover current, {
    required double focalX,
    required double focalY,
    required double headerFocalX,
    required double headerFocalY,
    ProgramCoverUpload? upload,
    bool removeImage = false,
  });
}
