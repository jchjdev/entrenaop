import 'package:equatable/equatable.dart';

/// Identidad visual del catálogo, independiente de la prescripción deportiva.
class EditorialCover extends Equatable {
  const EditorialCover({
    required this.cardUrl,
    required this.headerUrl,
    this.focalX = 0.5,
    this.focalY = 0.5,
    double? headerFocalX,
    double? headerFocalY,
  }) : headerFocalX = headerFocalX ?? focalX,
       headerFocalY = headerFocalY ?? focalY;
  final String cardUrl, headerUrl;
  final double focalX, focalY, headerFocalX, headerFocalY;
  @override
  List<Object?> get props => [
    cardUrl,
    headerUrl,
    focalX,
    focalY,
    headerFocalX,
    headerFocalY,
  ];
}
