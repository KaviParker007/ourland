import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ourlandnew/config.dart';
import 'package:http/http.dart' as http;
import 'package:ourlandnew/pages/login.dart';

class ApproveSpare extends StatefulWidget {
  final int jobCardId;
  const ApproveSpare({super.key, required this.jobCardId});

  @override
  State<ApproveSpare> createState() => _ApproveSpareState();
}

class _ApproveSpareState extends State<ApproveSpare> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isSubmitting = false;
  final String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;

  Map<String, dynamic> jobCard = {};
  int lastBatch = 0;
  List<dynamic> stockShortage = [];
  List<dynamic> pendingApproval = [];
  List<dynamic> availableItems = [];

  // One controller per pending approval row
  List<TextEditingController> qtyControllers = [];
  List<TextEditingController> itemRemarkControllers = [];

  // Global remark
  final TextEditingController globalRemarkController = TextEditingController();

  // Dynamically added items
  final List<Map<String, dynamic>> addedItems = [];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    globalRemarkController.dispose();
    for (final c in qtyControllers) c.dispose();
    for (final c in itemRemarkControllers) c.dispose();
    for (final item in addedItems) {
      (item['qty'] as TextEditingController).dispose();
      (item['remark'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('menu', 'job_card');
    username = prefs.getString('username');
    password = prefs.getString('password');
    if (username != null && password != null) {
      setState(() => isLoggedIn = true);
      await _fetchData();
    }
  }

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final uri = Uri.parse(
          '$baseUrl/drf_approve_spare_v2/?id=${widget.jobCardId}');
      print('[GET] $uri');
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json', 'authorization': _authHeader},
      );
      print('[GET] status: ${response.statusCode}');
      print('[GET] body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Dispose old controllers before reinitialising
        for (final c in qtyControllers) c.dispose();
        for (final c in itemRemarkControllers) c.dispose();

        setState(() {
          jobCard = (data['job_card'] as Map<String, dynamic>?) ?? {};
          lastBatch = (data['last_batch'] as int?) ?? 0;
          stockShortage = (data['stock_shortage'] as List<dynamic>?) ?? [];
          pendingApproval = (data['pending_approval'] as List<dynamic>?) ?? [];
          availableItems = (data['available_items'] as List<dynamic>?) ?? [];
          qtyControllers = List.generate(
            pendingApproval.length,
            (i) => TextEditingController(
                text: pendingApproval[i]['quantity_requested']?.toString() ?? ''),
          );
          itemRemarkControllers =
              List.generate(pendingApproval.length, (_) => TextEditingController());
        });
      } else {
        _showToast('Failed to load data: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showToast('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _addItem() {
    setState(() {
      addedItems.add({
        'item_id': null,
        'item_name': null,
        'qty': TextEditingController(),
        'remark': TextEditingController(),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      (addedItems[index]['qty'] as TextEditingController).dispose();
      (addedItems[index]['remark'] as TextEditingController).dispose();
      addedItems.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final List<Map<String, dynamic>> spares = [];

    // Pending approval items
    for (int i = 0; i < pendingApproval.length; i++) {
      final qty = qtyControllers[i].text.trim();
      if (qty.isEmpty) {
        _showToast(
            'Enter approved qty for "${pendingApproval[i]['item_name']}"',
            isError: true);
        return;
      }
      spares.add({
        'id': pendingApproval[i]['id'],
        'quantity_approved': qty,
        'approval_remark': itemRemarkControllers[i].text.trim(),
      });
    }

    // Additional items added by approver
    for (int i = 0; i < addedItems.length; i++) {
      final item = addedItems[i];
      if (item['item_id'] == null) {
        _showToast('Select an item for added row ${i + 1}', isError: true);
        return;
      }
      final qty = (item['qty'] as TextEditingController).text.trim();
      if (qty.isEmpty) {
        _showToast('Enter quantity for "${item['item_name']}"', isError: true);
        return;
      }
      spares.add({
        'item_id': item['item_id'],
        'quantity_approved': qty,
        'approval_remark':
            (item['remark'] as TextEditingController).text.trim(),
      });
    }

    setState(() => isSubmitting = true);
    try {
      final uri = Uri.parse('$baseUrl/drf_approve_spare_v2/');
      final body = jsonEncode({
        'id': widget.jobCardId,
        'approval_remark': globalRemarkController.text.trim(),
        'spares': spares,
      });
      print('[POST] $uri');
      print('[POST] body: $body');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'authorization': _authHeader},
        body: body,
      );
      print('[POST] status: ${response.statusCode}');
      print('[POST] body: ${response.body}');

      final decoded = jsonDecode(response.body);
      String message;
      if (decoded is Map) {
        if (decoded['shortages'] is List && (decoded['shortages'] as List).isNotEmpty) {
          final shortageLines = (decoded['shortages'] as List).join('\n');
          final errorMsg = decoded['error']?.toString() ?? '';
          message = errorMsg.isNotEmpty ? '$errorMsg\n$shortageLines' : shortageLines;
        } else {
          message = (decoded['message'] ?? decoded['detail'] ?? decoded['error'] ?? response.body).toString();
        }
      } else {
        message = response.body;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showToast(message.toString());
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/job_card_list');
        }
      } else {
        _showToast(message.toString(), isError: true);
      }
    } catch (e) {
      _showToast('Error: $e', isError: true);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      content: Text(msg),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── UI sections ────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.6))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      );

  Widget _buildJobCardCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  jobCard['vehicle']?.toString() ?? 'N/A',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _statusBadge(jobCard['status']?.toString() ?? ''),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _infoRow('Workshop', jobCard['workshop']?.toString() ?? 'N/A'),
            _infoRow('Work', jobCard['work']?.toString() ?? 'N/A'),
            _infoRow('Store', jobCard['workshop_store']?.toString() ?? 'N/A'),
            _infoRow('Batch', '#$lastBatch'),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade400),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: Colors.orange.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStockShortage() {
    if (stockShortage.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Text('Stock Shortage',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            // Header row
            Row(
              children: [
                _shortageCell('Item', flex: 3, isHeader: true),
                _shortageCell('Requested', isHeader: true),
                _shortageCell('Available', isHeader: true),
                _shortageCell('Shortage', isHeader: true),
              ],
            ),
            const Divider(color: Colors.red),
            ...stockShortage.map((item) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      _shortageCell(item['item']?.toString() ?? '', flex: 3),
                      _shortageCell(item['requested']?.toString() ?? ''),
                      _shortageCell(item['available']?.toString() ?? ''),
                      _shortageCell(item['shortage']?.toString() ?? '',
                          isBold: true),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _shortageCell(String text,
      {int flex = 1, bool isHeader = false, bool isBold = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? Colors.red.shade400 : Colors.red.shade800,
          fontSize: isHeader ? 11 : 13,
          fontWeight:
              (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildPendingApprovals() {
    if (pendingApproval.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pending Approvals'),
        ...List.generate(pendingApproval.length, (i) {
          final item = pendingApproval[i];
          final hasShortage = item['has_shortage'] == true;
          final remark = item['request_remark']?.toString() ?? '';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                  color: hasShortage
                      ? Colors.red.shade200
                      : Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name + shortage badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item['item_name']?.toString() ?? 'N/A',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      if (hasShortage)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Shortage',
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Meta row
                  Wrap(
                    spacing: 16,
                    children: [
                      _metaChip('Requested',
                          item['quantity_requested']?.toString() ?? 'N/A'),
                      _metaChip('Batch',
                          '#${item['request_batch']?.toString() ?? ''}'),
                      _metaChip('In Store',
                          item['available_in_store']?.toString() ?? 'N/A'),
                    ],
                  ),
                  if (remark.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Req. remark: $remark',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 12),
                  // Editable qty
                  TextField(
                    controller: qtyControllers[i],
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Editable remark
                  TextField(
                    controller: itemRemarkControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Approval Remark',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _metaChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style:
                TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  Widget _buildAdditionalItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Additional Items',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
        ),
        ...List.generate(addedItems.length, (i) {
          final item = addedItems[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item dropdown + remove button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: item['item_id'] as int?,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Item *',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          items: availableItems
                              .map<DropdownMenuItem<int>>((ai) =>
                                  DropdownMenuItem<int>(
                                    value: ai['id'] as int,
                                    child: Text(
                                        ai['name']?.toString() ?? '',
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              addedItems[i]['item_id'] = val;
                              addedItems[i]['item_name'] = availableItems
                                  .firstWhere(
                                      (ai) => ai['id'] == val,
                                      orElse: () => {'name': ''})['name'];
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _removeItem(i),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: item['qty'] as TextEditingController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantity *',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: item['remark'] as TextEditingController,
                    decoration: InputDecoration(
                      labelText: 'Remark',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGlobalRemark() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overall Approval Remark',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: globalRemarkController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter overall approval remark...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) return const LoginPage();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Approve Spare'),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchData,
                child: ListView(
                  children: [
                    _buildJobCardCard(),
                    _buildStockShortage(),
                    _buildPendingApprovals(),
                    _buildAdditionalItems(),
                    _buildGlobalRemark(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: isSubmitting
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Submit Approval',
                                  style: TextStyle(fontSize: 16)),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}
