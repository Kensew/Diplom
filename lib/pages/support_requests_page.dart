// lib/pages/support_requests_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class SupportRequestsPage extends StatefulWidget {
  const SupportRequestsPage({Key? key}) : super(key: key);

  @override
  State<SupportRequestsPage> createState() => _SupportRequestsPageState();
}

class _SupportRequestsPageState extends State<SupportRequestsPage> {
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _subscribeRealtime();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final records = await PocketBaseService.instance.pb
          .collection('support_requests')
          .getFullList(sort: '-created');

      _requests =
          records.map((record) {
            return {
              'id': record.id,
              'reason': record.data['reason'] as String? ?? '',
              'created': record.created,
            };
          }).toList();
    } catch (e) {
      _error = 'Error loading support requests: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _subscribeRealtime() async {
    await PocketBaseService.instance.pb
        .collection('support_requests')
        .subscribe('*', (event) {
          if (!mounted) return;

          final record = event.record;
          if (record == null) return;

          setState(() {
            if (event.action == 'create') {
              final exists = _requests.any((r) => r['id'] == record.id);

              if (!exists) {
                _requests.insert(0, {
                  'id': record.id,
                  'reason': record.data['reason'] as String? ?? '',
                  'created': record.created,
                });
              }
            } else if (event.action == 'update') {
              final index = _requests.indexWhere((r) => r['id'] == record.id);

              if (index != -1) {
                _requests[index] = {
                  'id': record.id,
                  'reason': record.data['reason'] as String? ?? '',
                  'created': record.created,
                };
              }
            } else if (event.action == 'delete') {
              _requests.removeWhere((r) => r['id'] == record.id);
            }

            _requests.sort((a, b) {
              final da = DateTime.tryParse(a['created'] as String? ?? '');
              final db = DateTime.tryParse(b['created'] as String? ?? '');

              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;

              return db.compareTo(da);
            });
          });
        });
  }

  @override
  void dispose() {
    PocketBaseService.instance.pb
        .collection('support_requests')
        .unsubscribe('*');

    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();

    return _requests.where((request) {
      final reason = (request['reason'] as String? ?? '').toLowerCase();
      return reason.contains(q);
    }).toList();
  }

  String _formatDate(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '—';
    return _fmt.format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: const BackButton(),
        title: const Text('Support Chats'),
      ),
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search issues…',
                  filled: true,
                  fillColor: cs.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: cs.primary),
                  ),
                  suffixIcon: Icon(Icons.search, color: cs.onSurface),
                ),
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child:
                    filtered.isEmpty
                        ? Center(
                          child: Text(
                            'No issues found',
                            style: TextStyle(color: cs.onSurface),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final request = filtered[i];
                            final id = request['id'] as String;
                            final reason = request['reason'] as String? ?? '';
                            final date = _formatDate(
                              request['created'] as String?,
                            );

                            return Card(
                              color: cs.secondary,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                title: Text(
                                  reason,
                                  style: TextStyle(color: cs.onSecondary),
                                ),
                                subtitle: Text(
                                  'Date: $date',
                                  style: TextStyle(color: cs.onSecondary),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: cs.onSecondary,
                                ),
                                onTap: () {
                                  context.push('/support/$id');
                                },
                              ),
                            );
                          },
                        ),
              ),
          ],
        ),
      ),
    );
  }
}
