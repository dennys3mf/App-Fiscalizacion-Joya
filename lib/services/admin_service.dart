import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/boleta_model.dart';
import '../models/user_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<BoletaModel>> listBoletas({
    String? placa,
    String? empresa,
    String? conductor,
    String? inspectorId,
    String? estado,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      HttpsCallable callable = _functions.httpsCallable('listBoletas');
      final result = await callable.call<Map<String, dynamic>>({
        'placa': placa,
        'empresa': empresa,
        'conductor': conductor,
        'inspectorId': inspectorId,
        'estado': estado,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      });

      List<dynamic> boletasData = result.data!['boletas'] ?? [];
      return boletasData.map((data) => BoletaModel.fromMap(data)).toList();
    } catch (e) {
      print('Error al listar boletas: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      HttpsCallable callable = _functions.httpsCallable('getDashboardData');
      final result = await callable.call<Map<String, dynamic>>({});
      return result.data!['data'] ?? {};
    } catch (e) {
      print('Error al obtener datos del dashboard: $e');
      return {};
    }
  }

  Future<UserModel?> crearInspector({
    required String email,
    required String password,
    required String name,
    required String code,
    required String phone,
  }) async {
    try {
      HttpsCallable callable = _functions.httpsCallable('crearInspector');
      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
        'password': password,
        'name': name,
        'code': code,
        'phone': phone,
      });

      Map<String, dynamic>? inspectorData = result.data!['inspector'];
      if (inspectorData != null) {
        return UserModel.fromMap(inspectorData);
      }
      return null;
    } catch (e) {
      print('Error al crear inspector: $e');
      return null;
    }
  }

  Future<List<UserModel>> getInspectores() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'inspector')
          .get();
      return querySnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error al obtener inspectores: $e');
      return [];
    }
  }

  Future<void> updateInspectorStatus(String uid, String status) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'status': status,
      });
    } catch (e) {
      print('Error al actualizar estado del inspector: $e');
      rethrow;
    }
  }
}


