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
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: whatsappController,
                decoration: const InputDecoration(labelText: 'WhatsApp'),
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
              await _updateUser(user['id_pengguna'], {
                'nama': namaController.text,
                'email': emailController.text,
                'whatsapp': whatsappController.text,
                'role': role,
              });
              if (mounted) Navigator.pop(context);
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    const Color(0xFF4CAF50).withOpacity(0.15),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF4CAF50),
                                  size: 32,
                                ),
                              ),
                              title: Text(
                                user['nama'] ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('ID: ${user['id_pengguna'] ?? '-'}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text('Email: ${user['email'] ?? '-'}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text('WhatsApp: ${user['whatsapp'] ?? '-'}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text('Role: ${user['role'] ?? '-'}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Color(0xFF4CAF50)),
                                    tooltip: 'Edit Pengguna',
                                    onPressed: () => _showEditDialog(user),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    tooltip: 'Hapus Pengguna',
                                    onPressed: () => _showDeleteDialog(
                                        user['id'], user['nama'] ?? '-'),
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
}
