import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  AppUser? _currentUser;
  List<UserRole> _userRoles = [];
  Map<String, String> _companyNames = {};
  Map<String, String> _garageNames = {};
  Map<String, AppUser> _grantedByUsers = {}; // Пользователи, которые выдали роли
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      
      if (user != null) {
        // Загрузить роли пользователя
        final rolesSnapshot = await _firestore
            .collection('user_roles')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .get();
        
        final roles = rolesSnapshot.docs
            .map((doc) => UserRole.fromFirestore(doc))
            .toList();
        
        // Загрузить названия компаний и гаражей
        Map<String, String> companyNames = {};
        Map<String, String> garageNames = {};
        Map<String, AppUser> grantedByUsers = {};
        
        for (var role in roles) {
          if (role.companyId != null && !companyNames.containsKey(role.companyId)) {
            final companyDoc = await _firestore.collection('companies').doc(role.companyId).get();
            if (companyDoc.exists) {
              companyNames[role.companyId!] = companyDoc.data()?['name'] ?? 'Без названия';
            }
          }
          
          if (role.garageId != null && !garageNames.containsKey(role.garageId)) {
            final garageDoc = await _firestore.collection('garages').doc(role.garageId).get();
            if (garageDoc.exists) {
              garageNames[role.garageId!] = garageDoc.data()?['name'] ?? 'Без названия';
            }
          }
          
          // Загрузить информацию о пользователе, который выдал роль
          if (role.grantedBy != null && !grantedByUsers.containsKey(role.grantedBy)) {
            final userDoc = await _firestore.collection('users').doc(role.grantedBy).get();
            if (userDoc.exists) {
              grantedByUsers[role.grantedBy!] = AppUser.fromFirestore(userDoc);
            }
          }
        }
        
        setState(() {
          _currentUser = user;
          _userRoles = roles;
          _companyNames = companyNames;
          _garageNames = garageNames;
          _grantedByUsers = grantedByUsers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    // AuthWrapper автоматически покажет RoleSelectionScreen
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      // Пользователь не авторизован - AuthWrapper покажет RoleSelectionScreen
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Rental Manager'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'profile':
                  // TODO: Открыть профиль пользователя
                  break;
                case 'logout':
                  _signOut();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 8),
                    Text(_currentUser!.displayName),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Выйти'),
                  ],
                ),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  _currentUser!.displayName.isNotEmpty 
                      ? _currentUser!.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Приветствие
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        _currentUser!.displayName.isNotEmpty 
                            ? _currentUser!.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добро пожаловать!',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _currentUser!.displayName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getPrimaryRole(),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Информация об учетной записи
            Text(
              'Информация об аккаунте',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow2('Email', _currentUser!.email, Icons.email),
                        const SizedBox(height: 12),
                        
                        _buildInfoRow2(
                          'Роли', 
                          _userRoles.isEmpty 
                              ? 'Гость' 
                              : _userRoles.map((r) {
                                  String roleDesc = r.roleType.description;
                                  if (r.companyId != null && _companyNames.containsKey(r.companyId)) {
                                    roleDesc += ' (${_companyNames[r.companyId]})';
                                  }
                                  if (r.garageId != null && _garageNames.containsKey(r.garageId)) {
                                    roleDesc += ' [${_garageNames[r.garageId]}]';
                                  }
                                  return roleDesc;
                                }).join(', '),
                          Icons.badge,
                        ),
                        const SizedBox(height: 12),
                        
                        if (_getOwnedCompany() != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildInfoRow2('Моя компания', _getOwnedCompany()!, Icons.business),
                          ),
                        
                        if (_getPrimaryGarage() != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildInfoRow2('Мой гараж', _getPrimaryGarage()!, Icons.garage),
                          ),
                        
                        // Всегда показываем руководителя (даже если его нет)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildInfoRow2(
                            'Мой руководитель', 
                            _getMyManager() ?? 'Нет руководителя',
                            Icons.person_pin,
                          ),
                        ),
                        
                        // Всегда показываем подчиненных (даже если их нет)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildInfoRow2(
                            'Мои подчиненные', 
                            _getSubordinatesInfo() ?? 'Нет подчиненных',
                            Icons.people,
                          ),
                        ),
                        
                        _buildInfoRow2(
                          'Организации', 
                          _currentUser!.organizations.isEmpty 
                              ? 'Нет доступных организаций'
                              : '${_currentUser!.organizations.length} организация(й)',
                          Icons.corporate_fare,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildInfoRow2(
                          'Дата регистрации', 
                          DateFormat('dd.MM.yyyy HH:mm').format(_currentUser!.createdAt),
                          Icons.calendar_today,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPrimaryRole() {
    if (_userRoles.isEmpty) return 'Гость';
    
    // Приоритет: owner > director > manager > agent > guest
    if (_userRoles.any((r) => r.roleType == RoleType.owner)) return RoleType.owner.description;
    if (_userRoles.any((r) => r.roleType == RoleType.director)) return RoleType.director.description;
    if (_userRoles.any((r) => r.roleType == RoleType.manager)) return RoleType.manager.description;
    if (_userRoles.any((r) => r.roleType == RoleType.agent)) return RoleType.agent.description;
    return RoleType.guest.description;
  }

  String? _getOwnedCompany() {
    if (_userRoles.isEmpty) return null;
    
    try {
      final ownerRole = _userRoles.firstWhere(
        (r) => r.roleType == RoleType.owner,
      );
      return ownerRole.companyId != null ? _companyNames[ownerRole.companyId] : null;
    } catch (e) {
      // Нет роли владельца, проверим другие роли с companyId
      for (var role in _userRoles) {
        if (role.companyId != null) {
          return _companyNames[role.companyId];
        }
      }
      return null;
    }
  }

  String? _getPrimaryGarage() {
    if (_userRoles.isEmpty) return null;
    
    try {
      final roleWithGarage = _userRoles.firstWhere(
        (r) => r.garageId != null,
      );
      return roleWithGarage.garageId != null ? _garageNames[roleWithGarage.garageId] : null;
    } catch (e) {
      return null;
    }
  }

  /// Получить руководителя (кто выдал мою роль)
  String? _getMyManager() {
    // Ищем роли, где указан grantedBy
    for (var role in _userRoles) {
      if (role.grantedBy != null && _grantedByUsers.containsKey(role.grantedBy)) {
        final grantor = _grantedByUsers[role.grantedBy]!;
        
        // Определяем роль руководителя
        String roleDesc = '';
        if (role.roleType == RoleType.manager) {
          roleDesc = 'Директор';
        } else if (role.roleType == RoleType.agent) {
          roleDesc = 'Менеджер/Директор';
        } else if (role.roleType == RoleType.director) {
          roleDesc = 'Владелец';
        }
        
        List<String> info = [grantor.displayName];
        if (roleDesc.isNotEmpty) {
          info.add(roleDesc);
        }
        if (role.companyId != null && _companyNames.containsKey(role.companyId)) {
          info.add('(${_companyNames[role.companyId]})');
        }
        
        return info.join(' - ');
      }
    }
    return null;
  }

  /// Получить информацию о подчиненных
  /// TODO: Это требует дополнительного запроса к БД для поиска пользователей,
  /// у которых grantedBy == currentUser.uid
  String? _getSubordinatesInfo() {
    // Пока что просто показываем, что пользователь может назначать роли
    if (_userRoles.any((r) => r.roleType == RoleType.owner || r.roleType == RoleType.director)) {
      return 'Может назначать менеджеров и агентов';
    }
    if (_userRoles.any((r) => r.roleType == RoleType.manager)) {
      return 'Может назначать агентов';
    }
    return null;
  }

  bool _hasRole(RoleType roleType) {
    return _userRoles.any((r) => r.roleType == roleType);
  }

  String _getRoleInfo(RoleType roleType) {
    final rolesOfType = _userRoles.where((r) => r.roleType == roleType).toList();
    if (rolesOfType.isEmpty) return 'Нет';
    
    return rolesOfType.map((role) {
      List<String> info = [];
      
      // Компания
      if (role.companyId != null && _companyNames.containsKey(role.companyId)) {
        info.add('в ${_companyNames[role.companyId]}');
      }
      
      // Гараж
      if (role.garageId != null && _garageNames.containsKey(role.garageId)) {
        info.add('гараж: ${_garageNames[role.garageId]}');
      }
      
      // Кто выдал роль (директор/владелец)
      if (role.grantedBy != null && _grantedByUsers.containsKey(role.grantedBy)) {
        final grantor = _grantedByUsers[role.grantedBy]!;
        info.add('назначил: ${grantor.displayName}');
      }
      
      return info.isEmpty ? role.roleType.description : '${role.roleType.description} (${info.join(', ')})';
    }).join('; ');
  }

  Widget _buildInfoRow2(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}