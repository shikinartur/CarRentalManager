import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility script to create test users for development
/// Run this once to create test users with different roles
Future<void> createTestUsers() async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  final testUsers = [
    {
      'email': 'm@m.m',
      'password': '111111',
      'displayName': 'M',
      'globalRole': 'MANAGER',
    },
    {
      'email': 'd@d.d',
      'password': '111111',
      'displayName': 'D',
      'globalRole': 'DIRECTOR',
    },
    {
      'email': 'o@o.o',
      'password': '111111',
      'displayName': 'O',
      'globalRole': 'OWNER',
    },
  ];

  for (var userData in testUsers) {
    try {
      // Check if user already exists
      final methods = await auth.fetchSignInMethodsForEmail(userData['email'] as String);
      
      UserCredential userCredential;
      
      if (methods.isEmpty) {
        // Create new user
        userCredential = await auth.createUserWithEmailAndPassword(
          email: userData['email'] as String,
          password: userData['password'] as String,
        );
        
        // Update display name
        await userCredential.user?.updateDisplayName(userData['displayName'] as String);
        
        print('✓ Created user: ${userData['email']}');
      } else {
        // User exists, sign in to get UID
        userCredential = await auth.signInWithEmailAndPassword(
          email: userData['email'] as String,
          password: userData['password'] as String,
        );
        
        print('✓ User already exists: ${userData['email']}');
      }

      // Create or update Firestore document
      await firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': userData['email'],
        'displayName': userData['displayName'],
        'globalRole': userData['globalRole'],
        'organizations': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('  → Firestore document created/updated for ${userData['email']}');
      
    } catch (e) {
      print('✗ Error creating user ${userData['email']}: $e');
    }
  }

  // Sign out after creating users
  await auth.signOut();
  print('\n✓ All test users created successfully!');
  print('You can now sign in with:');
  print('  - m@m.m (password: 111111) - MANAGER role');
  print('  - d@d.d (password: 111111) - DIRECTOR role');
  print('  - o@o.o (password: 111111) - OWNER role');
}
