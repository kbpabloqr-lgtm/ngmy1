import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

enum PasswordChangeResult {
  success,
  invalidCurrentPassword,
  noUserLoggedIn,
  failure,
}

class UserAccountService {
  static UserAccountService? _instance;
  static UserAccountService get instance => _instance ??= UserAccountService._();
  UserAccountService._();

  // Current user data
  UserAccount? _currentUser;
  UserAccount? get currentUser => _currentUser;

  /// Initialize the service and load current user
  Future<void> initialize() async {
    await _loadCurrentUser();
  }

  /// Load current user from storage
  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        _currentUser = UserAccount.fromJson(userData);
      } catch (e) {
        // Handle corrupted user data
        await logout();
      }
    }
  }

  /// Register a new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📝 [LocalAuth] Attempting registration for: $email');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user already exists
      final existingUsers = await _getAllUsers();
      if (existingUsers.any((user) => user.email == email)) {
        debugPrint('❌ [LocalAuth] User already exists: $email');
        throw Exception('User with this email already exists');
      }

      // Create new user with hashed password
  final hashedPassword = _hashPassword(password);
  debugPrint('📝 [LocalAuth] Hashing password for storage: "${_previewForLog(hashedPassword)}"');
      
      final newUser = UserAccount(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        email: email,
        password: hashedPassword,
        createdAt: DateTime.now(),
        isActive: true,
      );

      debugPrint('📝 [LocalAuth] Created user object: id=${newUser.id}, email=${newUser.email}');

      // Save user to storage
      await _saveUser(newUser);
      debugPrint('✅ [LocalAuth] User saved to SharedPreferences');
      
      // Set as current user
      _currentUser = newUser;
      await prefs.setString('current_user', jsonEncode(newUser.toJson()));
      debugPrint('✅ [LocalAuth] Registration successful');
      
      return true;
    } catch (e) {
      debugPrint('❌ [LocalAuth] Registration failed: $e');
      return false;
    }
  }

  /// Login user
  Future<bool> login(String email, String password) async {
    try {
      debugPrint('🔐 [LocalAuth] Attempting login for: $email');
      
      final users = await _getAllUsers();
      debugPrint('🔐 [LocalAuth] Found ${users.length} total users in storage');
      
      // Find user by email first
      var matchedUser = users.firstWhere(
        (u) => u.email == email,
        orElse: () => throw Exception('User not found'),
      );
      
      debugPrint('🔐 [LocalAuth] User found: ${matchedUser.email}');
      
      // Verify password matches
      final hashedPassword = _hashPassword(password);
      debugPrint('🔐 [LocalAuth] Stored password: "${_previewForLog(matchedUser.password)}"');
  debugPrint('🔐 [LocalAuth] Computed password: "${_previewForLog(hashedPassword)}"');
      
      if (matchedUser.password != hashedPassword) {
        if (matchedUser.password == password) {
          debugPrint('🔄 [LocalAuth] Legacy password detected. Migrating stored password to hashed format.');
          final updatedUser = matchedUser.copyWith(password: hashedPassword);
          await _saveUser(updatedUser);
          matchedUser = updatedUser;
          debugPrint('✅ [LocalAuth] Password migrated successfully');
        } else {
          debugPrint('❌ [LocalAuth] Password mismatch - stored password does not match input');
          throw Exception('Invalid password');
        }
      }

      debugPrint('✅ [LocalAuth] Password verified successfully');
      
      // Set as current user
      _currentUser = matchedUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(matchedUser.toJson()));
      
      debugPrint('✅ [LocalAuth] Login successful - user set as current');
      return true;
    } catch (e) {
      debugPrint('❌ [LocalAuth] Login failed: $e');
      return false;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }

  /// Check if user is logged in
  bool get isLoggedIn => _currentUser != null;

  /// Get all users (for admin purposes)
  Future<List<UserAccount>> _getAllUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList('all_users') ?? [];
      debugPrint('🔍 [LocalAuth] Retrieved ${usersJson.length} users from storage');
      
      return usersJson.map((json) {
        final userData = jsonDecode(json);
        return UserAccount.fromJson(userData);
      }).toList();
    } catch (e) {
      debugPrint('❌ [LocalAuth] Error retrieving users: $e');
      return [];
    }
  }

  /// Save user to storage
  Future<void> _saveUser(UserAccount user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await _getAllUsers();
      
      // Add or update user
      final existingIndex = users.indexWhere((u) => u.id == user.id);
      if (existingIndex != -1) {
        debugPrint('📝 [LocalAuth] Updating existing user: ${user.email}');
        users[existingIndex] = user;
      } else {
        debugPrint('📝 [LocalAuth] Adding new user: ${user.email}');
        users.add(user);
      }
      
      // Save to storage
      final usersJson = users.map((u) => jsonEncode(u.toJson())).toList();
      await prefs.setStringList('all_users', usersJson);
      debugPrint('✅ [LocalAuth] Successfully saved ${users.length} users to storage');
    } catch (e) {
      debugPrint('❌ [LocalAuth] Error saving user: $e');
    }
  }

  /// Expose all user accounts for administrative tooling.
  Future<List<UserAccount>> getAllUsers() async {
    final users = await _getAllUsers();
    return List<UserAccount>.from(users);
  }

  /// Administrative password reset that bypasses current password validation.
  Future<bool> adminUpdatePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      final users = await _getAllUsers();
      final targetIndex = users.indexWhere((user) => user.id == userId);
      if (targetIndex == -1) {
        return false;
      }

      final updatedUser = users[targetIndex].copyWith(
        password: _hashPassword(newPassword),
      );

      await _saveUser(updatedUser);

      if (_currentUser?.id == userId) {
        _currentUser = updatedUser;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(updatedUser.toJson()));
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Force a user to sign out by clearing the stored current user when matched.
  Future<bool> adminForceLogout(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentJson = prefs.getString('current_user');

      if (currentJson != null) {
        try {
          final currentData = jsonDecode(currentJson) as Map<String, dynamic>;
          final currentUser = UserAccount.fromJson(currentData);
          if (currentUser.id == userId) {
            await prefs.remove('current_user');
            if (_currentUser?.id == userId) {
              _currentUser = null;
            }
            return true;
          }
        } catch (_) {
          if (_currentUser?.id == userId) {
            await prefs.remove('current_user');
            _currentUser = null;
            return true;
          }
        }
      }

      if (_currentUser?.id == userId) {
        _currentUser = null;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Simple password hashing (use proper hashing in production)
  String _hashPassword(String password) {
    // In a real app, use proper password hashing like bcrypt
    return '${password.split('').reversed.join()}_hashed';
  }

  String _previewForLog(String value, {int max = 10}) {
    if (value.length <= max) {
      return value;
    }
    return '${value.substring(0, max)}...';
  }

  /// Verify a password against a user's stored password (for debugging)
  Future<bool> verifyPassword(String email, String password) async {
    try {
      final users = await _getAllUsers();
      final user = users.firstWhere(
        (u) => u.email == email,
        orElse: () => throw Exception('User not found'),
      );
      
      final hashedInput = _hashPassword(password);
      final match = user.password == hashedInput;
      
      debugPrint('🔍 [PasswordDebug] Email: $email');
      debugPrint('🔍 [PasswordDebug] Input password length: ${password.length}');
  debugPrint('🔍 [PasswordDebug] Stored hash: "${_previewForLog(user.password, max: 20)}"');
  debugPrint('🔍 [PasswordDebug] Computed hash: "${_previewForLog(hashedInput, max: 20)}"');
      debugPrint('🔍 [PasswordDebug] Password match: $match');
      
      return match;
    } catch (e) {
      debugPrint('❌ [PasswordDebug] Error: $e');
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? email,
  }) async {
    if (_currentUser == null) return false;

    try {
      final updatedUser = _currentUser!.copyWith(
        name: name ?? _currentUser!.name,
        email: email ?? _currentUser!.email,
      );

      await _saveUser(updatedUser);
      _currentUser = updatedUser;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(updatedUser.toJson()));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update the current user's password after validating the existing one.
  Future<PasswordChangeResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _currentUser;
    if (user == null) {
      return PasswordChangeResult.noUserLoggedIn;
    }

    if (user.password != _hashPassword(currentPassword)) {
      return PasswordChangeResult.invalidCurrentPassword;
    }

    try {
      final updatedUser = user.copyWith(password: _hashPassword(newPassword));
      await _saveUser(updatedUser);
      _currentUser = updatedUser;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(updatedUser.toJson()));

      return PasswordChangeResult.success;
    } catch (e) {
      return PasswordChangeResult.failure;
    }
  }

  /// Get user-specific preferences key
  String getUserKey(String key) {
    if (_currentUser == null) return key;
    return '${_currentUser!.id}_$key';
  }
}

class UserAccount {
  final String id;
  final String name;
  final String email;
  final String password;
  final DateTime createdAt;
  final bool isActive;

  UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      password: json['password'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? true,
    );
  }

  UserAccount copyWith({
    String? name,
    String? email,
    String? password,
    bool? isActive,
  }) {
    return UserAccount(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}