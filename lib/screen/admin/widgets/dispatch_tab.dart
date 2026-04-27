import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/admin_service.dart';
import '../../../models/device_model.dart';

/// Status filter options for the dispatch view.
enum _StatusFilter { all, online, onRide, offline }

class DispatchTab extends StatefulWidget {
  final AdminService adminService;
  final String? companyName;
  final String? companyId; // Added for ride stream scoping

  DispatchTab({super.key, AdminService? adminService, this.companyName, this.companyId})
      : adminService = adminService ?? AdminService();

  @override
  State<DispatchTab> createState() => _DispatchTabState();
}

class _DispatchTabState extends State<DispatchTab> {
  _StatusFilter _filter = _StatusFilter.all;
  String _searchQuery = '';
  late final TextEditingController _searchCtrl;

  // ── Palette ─────────────────────────────────────────────

  static const Color _card = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _orange = Color(0xFFF59E0B);
  static const Color _green = Color(0xFF10B981);
  static const Color _red = Color(0xFFEF4444);
  static const Color _blue = Color(0xFF60A5FA);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _faint = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────

  String _resolveStatus(Device d) {
    if (d.lastSeen != null &&
        DateTime.now().difference(d.lastSeen!).inMinutes > 2) {
      return 'disconnected';
    }
    return d.status; // 'running' | 'idle' | 'offline'
  }

  bool _passesFilter(Device d) {
    final s = _resolveStatus(d);
    switch (_filter) {
      case _StatusFilter.all:
        break;
      case _StatusFilter.online:
        if (s != 'idle') return false;
      case _StatusFilter.onRide:
        if (s != 'running') return false;
      case _StatusFilter.offline:
        if (s != 'offline' && s != 'disconnected') return false;
    }
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return d.plateNo.toLowerCase().contains(q) ||
        d.bodyNo.toLowerCase().contains(q) ||
        (d.currentDriver ?? '').toLowerCase().contains(q) ||
        d.serialNo.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Device>>(
      stream: widget.adminService.getDevicesStream(
        companyName: widget.companyName,
        companyId: widget.companyId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white)),
          );
        }

        final allDevices = snapshot.data ?? [];

        // Counts for the filter badges
        int cntAll = allDevices.length;
        int cntOnline =
            allDevices.where((d) => _resolveStatus(d) == 'idle').length;
        int cntOnRide =
            allDevices.where((d) => _resolveStatus(d) == 'running').length;
        int cntOffline = allDevices
            .where((d) =>
                _resolveStatus(d) == 'offline' ||
                _resolveStatus(d) == 'disconnected')
            .length;

        final visible =
            allDevices.where(_passesFilter).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page Header ───────────────────────────────────
            _PageHeader(
              cntAll: cntAll,
              cntOnline: cntOnline,
              cntOnRide: cntOnRide,
              cntOffline: cntOffline,
            ),
            const SizedBox(height: 16),

            // ── Toolbar: Search + Filters ─────────────────────
            Row(
              children: [
                // Search box
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search plate, body no, driver...',
                        hintStyle:
                            const TextStyle(color: _faint, fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            color: _faint, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    color: _faint, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: _card,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _border, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _orange, width: 1.5),
                        ),
                      ),
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.trim()),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Filter chips
                _FilterChip(
                  label: 'All',
                  count: cntAll,
                  color: _faint,
                  selected: _filter == _StatusFilter.all,
                  onTap: () =>
                      setState(() => _filter = _StatusFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Online',
                  count: cntOnline,
                  color: _orange,
                  selected: _filter == _StatusFilter.online,
                  onTap: () =>
                      setState(() => _filter = _StatusFilter.online),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'On Ride',
                  count: cntOnRide,
                  color: _green,
                  selected: _filter == _StatusFilter.onRide,
                  onTap: () =>
                      setState(() => _filter = _StatusFilter.onRide),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Offline',
                  count: cntOffline,
                  color: _red,
                  selected: _filter == _StatusFilter.offline,
                  onTap: () =>
                      setState(() => _filter = _StatusFilter.offline),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Device List ───────────────────────────────────
            Expanded(
              child: visible.isEmpty
                  ? _EmptyState(filter: _filter, query: _searchQuery)
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: visible.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _DeviceListRow(
                        device: visible[i],
                        resolvedStatus: _resolveStatus(visible[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Summary Header ────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final int cntAll, cntOnline, cntOnRide, cntOffline;

  const _PageHeader(
      {required this.cntAll,
      required this.cntOnline,
      required this.cntOnRide,
      required this.cntOffline});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Real-Time Dispatch Monitoring',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Live status, sales, and trip stats for all registered devices',
                style: TextStyle(
                    color: _DispatchTabState._faint, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        _SumBadge(label: 'TOTAL', value: cntAll, color: _DispatchTabState._faint),
        const SizedBox(width: 10),
        _SumBadge(
            label: 'ON RIDE', value: cntOnRide, color: _DispatchTabState._green),
        const SizedBox(width: 10),
        _SumBadge(
            label: 'ONLINE', value: cntOnline, color: _DispatchTabState._orange),
        const SizedBox(width: 10),
        _SumBadge(
            label: 'OFFLINE', value: cntOffline, color: _DispatchTabState._red),
      ],
    );
  }
}

class _SumBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SumBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : _DispatchTabState._card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : _DispatchTabState._border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: selected ? color : _DispatchTabState._faint,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.25) : _DispatchTabState._border,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: selected ? color : _DispatchTabState._faint,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Device List Row ───────────────────────────────────────────────────────────

class _DeviceListRow extends StatelessWidget {
  final Device device;
  final String resolvedStatus;

  const _DeviceListRow({required this.device, required this.resolvedStatus});

  Color get _statusColor {
    switch (resolvedStatus) {
      case 'running':
        return _DispatchTabState._green;
      case 'idle':
        return _DispatchTabState._orange;
      case 'disconnected':
        return _DispatchTabState._red;
      default:
        return _DispatchTabState._faint;
    }
  }

  String get _statusLabel {
    switch (resolvedStatus) {
      case 'running':
        return 'ON RIDE';
      case 'idle':
        return 'IDLE';
      case 'disconnected':
        return 'DISCONNECTED';
      default:
        return 'OFFLINE';
    }
  }

  IconData get _statusIcon {
    switch (resolvedStatus) {
      case 'running':
        return Icons.local_taxi;
      case 'idle':
        return Icons.check_circle;
      case 'disconnected':
        return Icons.signal_wifi_off;
      default:
        return Icons.offline_bolt;
    }
  }

  String _fmtDuration(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${secs}s';
  }

  String _fmtDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(2)}km' : '${m.toStringAsFixed(0)}m';

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final currFmt = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final timeFmt = DateFormat('hh:mm a');

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _DispatchTabState._card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DispatchTabState._border, width: 1),
      ),
      child: Row(
        children: [
          // Status Indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),

          // Plate & Body No
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.plateNo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Body #${device.bodyNo}',
                  style: const TextStyle(
                    color: _DispatchTabState._faint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Status Badge
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(_statusIcon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  _statusLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Driver
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DRIVER',
                  style: TextStyle(
                    color: _DispatchTabState._faint,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  device.currentDriver ?? '---',
                  style: TextStyle(
                    color: device.currentDriver != null
                        ? Colors.white
                        : _DispatchTabState._faint,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Stats
          _ListStat(
            label: 'SALES',
            value: currFmt.format(device.dailySales),
            color: _DispatchTabState._orange,
            width: 100,
          ),
          _ListStat(
            label: 'DISTANCE',
            value: _fmtDist(device.dailyDistanceMeters),
            color: _DispatchTabState._blue,
            width: 80,
          ),
          _ListStat(
            label: 'WAIT',
            value: _fmtDuration(device.dailyWaitingSeconds),
            color: _DispatchTabState._purple,
            width: 70,
          ),

          // Last Seen
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'LAST SEEN',
                style: TextStyle(
                  color: _DispatchTabState._faint,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                device.lastSeen != null ? timeFmt.format(device.lastSeen!) : '---',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Small Stat for List ───────────────────────────────────────────────────────

class _ListStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double width;

  const _ListStat({
    required this.label,
    required this.value,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _StatusFilter filter;
  final String query;
  const _EmptyState({required this.filter, required this.query});

  @override
  Widget build(BuildContext context) {
    final isSearch = query.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSearch ? Icons.search_off : Icons.devices_other,
              size: 56, color: _DispatchTabState._border),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'No devices match "$query"' : 'No devices in this category',
            style: const TextStyle(
                color: _DispatchTabState._faint, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
