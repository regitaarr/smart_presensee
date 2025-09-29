import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class FirestoreHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Helper method untuk query dengan error handling yang lebih baik
  static Future<QuerySnapshot> safeQuery({
    required String collection,
    List<Map<String, dynamic>>? whereConditions,
    int? limit,
    String? orderBy,
    bool descending = false,
  }) async {
    try {
      log('=== FirestoreHelper: Querying $collection ===');

      Query query = _firestore.collection(collection);

      // Apply where conditions
      if (whereConditions != null) {
        for (var condition in whereConditions) {
          String field = condition['field'];
          String operator = condition['operator'];
          dynamic value = condition['value'];

          switch (operator) {
            case '==':
              query = query.where(field, isEqualTo: value);
              break;
            case '!=':
              query = query.where(field, isNotEqualTo: value);
              break;
            case '>':
              query = query.where(field, isGreaterThan: value);
              break;
            case '>=':
              query = query.where(field, isGreaterThanOrEqualTo: value);
              break;
            case '<':
              query = query.where(field, isLessThan: value);
              break;
            case '<=':
              query = query.where(field, isLessThanOrEqualTo: value);
              break;
            case 'in':
              query = query.where(field, whereIn: value);
              break;
            case 'array-contains':
              query = query.where(field, arrayContains: value);
              break;
          }
        }
      }

      // Apply order by
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      log('FirestoreHelper: Executing query...');
      QuerySnapshot result = await query.get();
      log('FirestoreHelper: Query successful, found ${result.docs.length} documents');

      return result;
    } catch (e) {
      log('FirestoreHelper: Error querying $collection: $e');
      throw Exception('Gagal memuat data dari $collection: ${e.toString()}');
    }
  }

  /// Helper method untuk mendapatkan dokumen tunggal
  static Future<DocumentSnapshot> safeGetDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      log('=== FirestoreHelper: Getting document $documentId from $collection ===');

      DocumentSnapshot result =
          await _firestore.collection(collection).doc(documentId).get();

      log('FirestoreHelper: Document get successful');
      return result;
    } catch (e) {
      log('FirestoreHelper: Error getting document $documentId from $collection: $e');
      throw Exception('Gagal memuat dokumen dari $collection: ${e.toString()}');
    }
  }

  /// Helper method untuk menambah dokumen
  static Future<DocumentReference> safeAddDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      log('=== FirestoreHelper: Adding document to $collection ===');

      DocumentReference result =
          await _firestore.collection(collection).add(data);

      log('FirestoreHelper: Document added successfully with ID: ${result.id}');
      return result;
    } catch (e) {
      log('FirestoreHelper: Error adding document to $collection: $e');
      throw Exception('Gagal menambah dokumen ke $collection: ${e.toString()}');
    }
  }

  /// Helper method untuk update dokumen
  static Future<void> safeUpdateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      log('=== FirestoreHelper: Updating document $documentId in $collection ===');

      await _firestore.collection(collection).doc(documentId).update(data);

      log('FirestoreHelper: Document updated successfully');
    } catch (e) {
      log('FirestoreHelper: Error updating document $documentId in $collection: $e');
      throw Exception(
          'Gagal mengupdate dokumen di $collection: ${e.toString()}');
    }
  }

  /// Helper method untuk delete dokumen
  static Future<void> safeDeleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      log('=== FirestoreHelper: Deleting document $documentId from $collection ===');

      await _firestore.collection(collection).doc(documentId).delete();

      log('FirestoreHelper: Document deleted successfully');
    } catch (e) {
      log('FirestoreHelper: Error deleting document $documentId from $collection: $e');
      throw Exception(
          'Gagal menghapus dokumen dari $collection: ${e.toString()}');
    }
  }

  /// Helper method untuk mengecek koneksi Firestore
  static Future<bool> checkConnection() async {
    try {
      log('=== FirestoreHelper: Checking connection ===');

      // Try to get a simple document to test connection
      await _firestore.collection('test').limit(1).get();

      log('FirestoreHelper: Connection successful');
      return true;
    } catch (e) {
      log('FirestoreHelper: Connection failed: $e');
      return false;
    }
  }
}