import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserList extends StatefulWidget {
  const AdminUserList({super.key});

  @override
  State<AdminUserList> createState() => _AdminUserListState();
}

class _AdminUserListState extends State<AdminUserList> {
  bool isLoading = true;
  List<Map<String, dynamic>> userList = [];
  List<Map<String, dynamic>> filteredUserList = [];
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRole = 'Semua Role';
  final List<String> _roleList = ['admin', 'walikelas'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
    });
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('pengguna').get();
      List<Map<String, dynamic>> tempList = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Jika role adalah walikelas, ambil data kelas yang diampu
        if (data['role'] == 'walikelas') {
          try {
            QuerySnapshot walikelasSnapshot = await FirebaseFirestore.instance
                .collection('walikelas')
                .where('id_pengguna', isEqualTo: data['id_pengguna'])
                .limit(1)
                .get();

            if (walikelasSnapshot.docs.isNotEmpty) {
              Map<String, dynamic> walikelasData =
                  walikelasSnapshot.docs.first.data() as Map<String, dynamic>;
              data['kelas_diampu'] = walikelasData['kelasku'] ?? 'Belum diisi';
              data['nip'] = walikelasData['nip'] ?? 'Belum diisi';
            } else {
              data['kelas_diampu'] = 'Belum diisi';
              data['nip'] = 'Belum diisi';
            }
          } catch (e) {
            data['kelas_diampu'] = 'Error loading data';
            data['nip'] = 'Error loading data';
          }
        }

        tempList.add(data);
      }

      setState(() {
        userList = tempList;
        _applyFilter();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal memuat data pengguna: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _applyFilter() {
    setState(() {
      filteredUserList = userList.where((user) {
        final matchesSearch = (user['nama'] ?? '')
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            (user['email'] ?? '')
                .toLowerCase()
                .contains(searchQuery.toLowerCase());
        final matchesRole = _selectedRole == null ||
            _selectedRole == 'Semua Role' ||
            (user['role'] ?? '').toLowerCase() == _selectedRole!.toLowerCase();
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  void _filterUsers(String query) {
    setState(() {
      searchQuery = query;
      _applyFilter();
    });
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('pengguna')
          .doc(userId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pengguna berhasil dihapus'),
            backgroundColor: Colors.green),
      );
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal menghapus pengguna: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateUser(
      String id_pengguna, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('pengguna')
        .doc(id_pengguna)
        .update(data);
    await _loadUsers(); // refresh data setelah update
  }

  void _showDeleteDialog(String userId, String nama) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Yakin ingin menghapus pengguna "$nama"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteUser(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> user) {
    final namaController = TextEditingController(text: user['nama'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    final whatsappController =
        TextEditingController(text: user['whatsapp'] ?? '');
    String role = (user['role'] ?? '').toLowerCase();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Pengguna'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID Pengguna: ${user['id_pengguna'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Email harus mengandung karakter @',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp',
                  helperText: 'Nomor harus 13 digit dan diawali dengan 62',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role.isNotEmpty ? role : null,
                decoration: const InputDecoration(labelText: 'Role'),
                items: _roleList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(_formatRoleForDisplay(value)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) role = newValue;
                },
              ),
              // Tampilkan informasi kelas untuk wali kelas (read-only)
              if (user['role'] == 'walikelas') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Wali Kelas (Tidak Dapat Diubah)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('NIP: ${user['nip'] ?? 'Belum diisi'}',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                          'Kelas yang Diampu: ${user['kelas_diampu'] ?? 'Belum diisi'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validasi WhatsApp
              if (!whatsappController.text.startsWith('62') ||
                  whatsappController.text.length != 13 ||
                  !RegExp(r'^\d+$').hasMatch(whatsappController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Nomor WhatsApp harus 13 digit dan diawali dengan 62'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Validasi Email
              if (!emailController.text.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email harus mengandung karakter @'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await _updateUser(user['id_pengguna'], {
                'nama': namaController.text,
                'email': emailController.text,
                'whatsapp': whatsappController.text,
                'role': role,
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data pengguna berhasil diperbarui'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Data Pengguna',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari pengguna...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      searchQuery = value;
                      _applyFilter();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      hint: const Text('Semua Role'),
                      underline: const SizedBox(),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'Semua Role',
                          child: Text('Semua Role'),
                        ),
                        ..._roleList.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(_formatRoleForDisplay(value)),
                          );
                        }).toList(),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                          _applyFilter();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50))))
                : filteredUserList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.supervised_user_circle_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada pengguna ditemukan',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filteredUserList.length,
                        itemBuilder: (context, index) {
                          final user = filteredUserList[index];
                          final isWalikelas = user['role'] == 'walikelas';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Avatar dengan badge role
                                  Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF4CAF50),
                                              const Color(0xFF66BB6A),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isWalikelas 
                                                ? const Color(0xFF2196F3) 
                                                : const Color(0xFFFF9800),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            isWalikelas ? Icons.school : Icons.admin_panel_settings,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  // Informasi Pengguna
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Nama dan Badge Role
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user['nama'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: Color(0xFF2C3E50),
                                                  letterSpacing: 0.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isWalikelas
                                                      ? [const Color(0xFF2196F3), const Color(0xFF42A5F5)]
                                                      : [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                _formatRoleForDisplay(user['role'] ?? '-'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // NIP (ditampilkan setelah nama)
                                        if (isWalikelas && user['nip'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF2196F3).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.badge,
                                                    size: 16,
                                                    color: Color(0xFF2196F3),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    'NIP: ${user['nip']}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF2196F3),
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        // ID Pengguna
                                        _buildInfoRow(
                                          Icons.fingerprint,
                                          'ID',
                                          user['id_pengguna'] ?? '-',
                                          const Color(0xFF9C27B0),
                                        ),
                                        const SizedBox(height: 6),
                                        // Email
                                        _buildInfoRow(
                                          Icons.email_outlined,
                                          'Email',
                                          user['email'] ?? '-',
                                          const Color(0xFF4CAF50),
                                        ),
                                        const SizedBox(height: 6),
                                        // WhatsApp
                                        _buildInfoRow(
                                          Icons.phone_android,
                                          'WhatsApp',
                                          user['whatsapp'] ?? '-',
                                          const Color(0xFF00BCD4),
                                        ),
                                        // Kelas yang Diampu (untuk wali kelas)
                                        if (isWalikelas) ...[
                                          const SizedBox(height: 6),
                                          _buildInfoRow(
                                            Icons.class_,
                                            'Kelas',
                                            user['kelas_diampu'] ?? '-',
                                            const Color(0xFFFF9800),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Action Buttons
                                  Column(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: Color(0xFF4CAF50),
                                            size: 22,
                                          ),
                                          tooltip: 'Edit Pengguna',
                                          onPressed: () => _showEditDialog(user),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 22,
                                          ),
                                          tooltip: 'Hapus Pengguna',
                                          onPressed: () => _showDeleteDialog(
                                              user['id'], user['nama'] ?? '-'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatRoleForDisplay(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'walikelas':
        return 'Wali Kelas';
      default:
        return role;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
