import 'package:cloud_firestore/cloud_firestore.dart';

class SensorNodeModel {
  final String firebaseId;
  final String? noId;
  final String nome;
  final String gatewayCode;
  final String? status;
  final String? tipo;
  final String? ultimoContacto;

  const SensorNodeModel({
    required this.firebaseId,
    required this.nome,
    required this.gatewayCode,
    this.noId,
    this.status,
    this.tipo,
    this.ultimoContacto,
  });

  factory SensorNodeModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SensorNodeModel(
      firebaseId: doc.id,
      noId: _readNoId(data, doc.id),
      nome: data['nome']?.toString() ?? 'Nó ${doc.id}',
      gatewayCode: data['gateway_code']?.toString() ?? '',
      status: data['status']?.toString(),
      tipo: data['tipo']?.toString(),
      ultimoContacto: data['ultimo_contacto']?.toString(),
    );
  }

  static String? _readNoId(Map<String, dynamic> data, String docId) {
    final explicit = data['no_id'] ?? data['id_no'];
    if (explicit != null && explicit.toString().trim().isNotEmpty) {
      return explicit.toString();
    }
    return int.tryParse(docId) != null ? docId : null;
  }

  Map<String, dynamic> toAssociationPayload({
    required int farmId,
    required int landId,
  }) {
    return {
      'farm_id': farmId,
      'land_id': landId,
      'gateway_code': gatewayCode.toUpperCase(),
      'sensor_firebase_id': firebaseId,
      'sensor_no_id': noId,
      'sensor_nome': nome,
      'sensor_tipo': tipo,
      'sensor_status': status,
      'ultimo_contacto': ultimoContacto,
    };
  }
}
