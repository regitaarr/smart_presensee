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
        final name = (user['nama'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        return name.contains(searchQuery.toLowerCase()) ||
            email.contains(searchQuery.toLowerCase());
      }).toList();
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
      String userId, Map<String, dynamic> updatedData) async {
    try {
      await FirebaseFirestore.instance
          .collection('pengguna')
          .doc(userId)
          .update(updatedData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Data pengguna berhasil diperbarui'),
            backgroundColor: Colors.green),
      );
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal memperbarui data pengguna: $e'),
            backgroundColor: Colors.red),
      );
    }
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
    final TextEditingController namaController =
        TextEditingController(text: user['nama']);
    final TextEditingController emailController =
        TextEditingController(text: user['email']);
    final TextEditingController nipController =
        TextEditingController(text: user['nip'] ?? '');
    String selectedRole = user['role'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Pengguna'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(
                      value: 'walikelas', child: Text('Wali Kelas')),
                  DropdownMenuItem(value: 'guru', child: Text('Guru')),
                ],
                onChanged: (value) {
                  selectedRole = value!;
                },
              ),
              if (selectedRole == 'wali kelas') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: nipController,
                  decoration: const InputDecoration(
                    labelText: 'NIP',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Map<String, dynamic> updatedData = {
                'nama': namaController.text,
                'email': emailController.text,
                'role': selectedRole,
              };

              if (selectedRole == 'wali kelas') {
                updatedData['nip'] = nipController.text;
              }

              Navigator.of(context).pop();
              _updateUser(user['id'], updatedData);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Daftar Pengguna',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama atau email...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                searchQuery = value;
                _applyFilter();
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50))))
                : filteredUserList.isEmpty
                    ? const Center(child: Text('Tidak ada data pengguna'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUserList.length,
                        itemBuilder: (context, index) {
                          final user = filteredUserList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF4CAF50),
                                child: Text(
                                  (user['nama'] ?? '?').toString().isNotEmpty
                                      ? user['nama'][0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(user['nama'] ?? '-'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email'] ?? '-'),
                                  Text('Role: ${user['role'] ?? '-'}'),
                                  if ((user['role'] ?? '')
                                          .toString()
                                          .toLowerCase() ==
                                      'wali kelas')
                                    Text('NIP: ${user['nip'] ?? '-'}'),
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
}
