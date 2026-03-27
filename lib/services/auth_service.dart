// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AuthService {
  final _auth         = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _db           = FirebaseFirestore.instance;

  User? get currentUser       => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    // Limpiar sesión cacheada para evitar ApiException 10
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      debugPrint('⚠️  Usuario canceló el selector');
      return null;
    }

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      debugPrint('❌ idToken null — verifica proveedor Google en Firebase Console');
      return null;
    }

    final credential = GoogleAuthProvider.credential(
      idToken:     googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user   = result.user;
    if (user == null) return null;

    // Refrescar token para obtener Custom Claims actualizados
    await user.getIdToken(true);

    // Verificar que existe en /users (creado por la app loja)
    final snap = await _db.collection('users').doc(user.uid).get();
    if (!snap.exists) {
      debugPrint('❌ UID no encontrado en /users');
      await _signOutBoth();
      return null;
    }

    // Verificar rol admin en Custom Claims
    final tokenResult = await user.getIdTokenResult();
    final roles = tokenResult.claims?['roles'];
    debugPrint('ℹ️  Claims roles: $roles');

    final isAdmin = roles is List
        ? roles.contains('admin')
        : roles.toString().contains('admin');

    if (!isAdmin) {
      debugPrint('❌ Sin rol admin — acceso denegado');
      await _signOutBoth();
      return null;
    }

    debugPrint('✅ Acceso concedido: ${user.email}');
    return user;
  }

  /// Para workers: solo verificamos que existe en /users.
  /// El workerId vendrá de los claims y se usa para filtrar datos.
  Future<User?> signInWorker() async {
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) return null;

    final credential = GoogleAuthProvider.credential(
      idToken:     googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user   = result.user;
    if (user == null) return null;

    await user.getIdToken(true);

    final snap = await _db.collection('users').doc(user.uid).get();
    if (!snap.exists) {
      await _signOutBoth();
      return null;
    }

    final tokenResult = await user.getIdTokenResult();
    final roles = tokenResult.claims?['roles'];

    final hasAccess = roles is List
        ? (roles.contains('admin') || roles.contains('worker'))
        : (roles.toString().contains('admin') || roles.toString().contains('worker'));

    if (!hasAccess) {
      await _signOutBoth();
      return null;
    }

    return user;
  }

  /// Devuelve el workerId del token si el usuario es worker puro,
  /// null si es admin (ve todo).
  Future<String?> getWorkerIdFromClaims() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final result = await user.getIdTokenResult();
    return result.claims?['workerId'] as String?;
  }

  /// true si el usuario tiene rol admin.
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult();
    final roles  = result.claims?['roles'];
    return roles is List
        ? roles.contains('admin')
        : roles.toString().contains('admin');
  }

  Future<void> signOut() => _signOutBoth();

  Future<void> _signOutBoth() async {
    try { await _auth.signOut(); } catch (_) {}
    try { await _googleSignIn.signOut(); } catch (_) {}
  }
}
