import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Stream to listen to auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Sign Up with Email and Password
  Future<User?> signUpWithEmailPassword({
    required String email, 
    required String password, 
    required String name, 
    String? role
  }) async {
    try {
    UserCredential userCredential = await _firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: password);

    User? user = userCredential.user;
    if (user == null) return null;

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "name": name,
      "role": role ?? "student",
      "email": email,
      "uid": user.uid,
      "createdAt": FieldValue.serverTimestamp(),
      "strike": 0,
    });
    return user;
  } catch (e) {
      debugPrint("SignUp error: $e");
      rethrow;
    }
  }

  // Sign In with Email and Password
  Future<UserCredential?> signInWithEmailPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle errors (e.g., user-not-found, wrong-password)
      debugPrint("Error during sign in: ${e.message}");
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

// TODO: Add Google Sign In, Password Reset, etc.
}
