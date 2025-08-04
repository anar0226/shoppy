import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class KYCVerificationPage extends StatefulWidget {
  const KYCVerificationPage({super.key});

  @override
  State<KYCVerificationPage> createState() => _KYCVerificationPageState();
}

class _KYCVerificationPageState extends State<KYCVerificationPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _kycApplications = [];
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadKYCApplications();
  }

  Future<void> _loadKYCApplications() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all stores with KYC documents uploaded
      final storesSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('idCardFrontImage', isNotEqualTo: null)
          .get();

      List<Map<String, dynamic>> applications = [];

      for (final storeDoc in storesSnapshot.docs) {
        final storeData = storeDoc.data();
        final kycStatus = storeData['kycStatus'] ?? 'pending';
        // KYC documents are stored directly in store data, not in a nested object
        final kycDocuments = {
          'idCardFront': storeData['idCardFrontImage'],
          'idCardBack': storeData['idCardBackImage'],
        };
        final kycSubmittedAt = storeData['kycSubmittedAt'];
        final kycVerifiedAt = storeData['kycVerifiedAt'];
        final kycRejectedAt = storeData['kycRejectedAt'];
        final kycRejectionReason = storeData['kycRejectionReason'];

        applications.add({
          'storeId': storeDoc.id,
          'storeData': storeData,
          'kycStatus': kycStatus,
          'kycDocuments': kycDocuments,
          'kycSubmittedAt': kycSubmittedAt,
          'kycVerifiedAt': kycVerifiedAt,
          'kycRejectedAt': kycRejectedAt,
          'kycRejectionReason': kycRejectionReason,
        });
      }

      // Sort by submission date (newest first)
      applications.sort((a, b) {
        final aDate = a['kycSubmittedAt'] as Timestamp?;
        final bDate = b['kycSubmittedAt'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _kycApplications = applications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading KYC applications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyKYC(String storeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .update({
        'kycStatus': 'verified',
        'kycVerifiedAt': FieldValue.serverTimestamp(),
        'kycVerifiedBy': 'super_admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC verification successful'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadKYCApplications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying KYC: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectKYC(String storeId, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .update({
        'kycStatus': 'rejected',
        'kycRejectedAt': FieldValue.serverTimestamp(),
        'kycRejectedBy': 'super_admin',
        'kycRejectionReason': reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _loadKYCApplications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting KYC: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectionDialog(String storeId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject KYC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _rejectKYC(storeId, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showDocumentViewer(String title, String? documentUrl) {
    if (documentUrl == null || documentUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: Image.network(
                  documentUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text('Failed to load image'),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Open in new tab/window
                      // You can implement this based on your platform
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Full Size'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredApplications {
    List<Map<String, dynamic>> filtered = _kycApplications;

    // Apply status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((app) {
        return app['kycStatus'] == _filterStatus;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final storeData = app['storeData'];
        final storeName = storeData['name']?.toString().toLowerCase() ?? '';
        final ownerName =
            storeData['ownerName']?.toString().toLowerCase() ?? '';
        final phone = storeData['phone']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return storeName.contains(query) ||
            ownerName.contains(query) ||
            phone.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KYC Verification',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review and verify store identity documents',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _loadKYCApplications,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Filters and Search
            Row(
              children: [
                // Status Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _filterStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'verified', child: Text('Verified')),
                      DropdownMenuItem(
                          value: 'rejected', child: Text('Rejected')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value!;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Search
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search stores...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Statistics Cards
            Row(
              children: [
                _buildStatCard(
                  'Total Applications',
                  _kycApplications.length.toString(),
                  Icons.folder,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Pending',
                  _kycApplications
                      .where((a) => a['kycStatus'] == 'pending')
                      .length
                      .toString(),
                  Icons.pending,
                  Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Verified',
                  _kycApplications
                      .where((a) => a['kycStatus'] == 'verified')
                      .length
                      .toString(),
                  Icons.verified_user,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Rejected',
                  _kycApplications
                      .where((a) => a['kycStatus'] == 'rejected')
                      .length
                      .toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Applications List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredApplications.isEmpty
                      ? const Center(
                          child: Text(
                            'No KYC applications found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredApplications.length,
                          itemBuilder: (context, index) {
                            final application = _filteredApplications[index];
                            return _buildApplicationCard(application);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final storeData = application['storeData'];
    final storeId = application['storeId'];
    final kycStatus = application['kycStatus'];
    final kycDocuments =
        Map<String, dynamic>.from(application['kycDocuments'] ?? {});
    final kycSubmittedAt = application['kycSubmittedAt'];
    // final kycVerifiedAt = application['kycVerifiedAt'];
    // final kycRejectedAt = application['kycRejectedAt'];
    final kycRejectionReason = application['kycRejectionReason'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    (storeData['name'] ?? 'S').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeData['name'] ?? 'Unknown Store',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Owner: ${storeData['ownerName'] ?? 'Unknown'} | Phone: ${storeData['phone'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (kycSubmittedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(kycSubmittedAt.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusChip(kycStatus),
              ],
            ),

            const SizedBox(height: 20),

            // KYC Documents
            const Text(
              'Identity Documents',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Check if any documents exist
            if (kycDocuments['idCardFront'] != null ||
                kycDocuments['idCardBack'] != null) ...[
              Row(
                children: [
                  if (kycDocuments['idCardFront'] != null)
                    Expanded(
                      child: _buildDocumentThumbnail(
                        'ID Card Front',
                        kycDocuments['idCardFront'],
                        () => _showDocumentViewer(
                            'ID Card Front', kycDocuments['idCardFront']),
                      ),
                    ),
                  if (kycDocuments['idCardFront'] != null &&
                      kycDocuments['idCardBack'] != null)
                    const SizedBox(width: 12),
                  if (kycDocuments['idCardBack'] != null)
                    Expanded(
                      child: _buildDocumentThumbnail(
                        'ID Card Back',
                        kycDocuments['idCardBack'],
                        () => _showDocumentViewer(
                            'ID Card Back', kycDocuments['idCardBack']),
                      ),
                    ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning,
                        color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No KYC documents uploaded yet. Store owner needs to upload ID card images.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Document Retention Notice
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'KYC documents are stored securely and will be automatically deleted after 90 days of verification or rejection for privacy compliance.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Rejection Reason
            if (kycStatus == 'rejected' && kycRejectionReason != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cancel,
                            color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Rejection Reason',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kycRejectionReason,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            if (kycStatus == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _verifyKYC(storeId),
                      icon: const Icon(Icons.verified_user),
                      label: const Text('Verify KYC'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectionDialog(storeId),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Reject KYC'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentThumbnail(
      String title, String documentUrl, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(
              Icons.image,
              size: 32,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to view',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'verified':
        color = Colors.green;
        icon = Icons.verified_user;
        label = 'Verified';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
