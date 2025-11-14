import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/store_data_store.dart';
import '../models/store_models.dart';
import '../widgets/floating_header.dart';

class AdminStoreScreen extends StatefulWidget {
  const AdminStoreScreen({super.key});

  @override
  State<AdminStoreScreen> createState() => _AdminStoreScreenState();
}

class _AdminStoreScreenState extends State<AdminStoreScreen>
    with SingleTickerProviderStateMixin {
  final store = StoreDataStore.instance;

  final _labelCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _weightCtrl = TextEditingController(text: '1');
  final _imageCtrl = TextEditingController();
  PrizeType _type = PrizeType.money;
  final Color _color = const Color(0xFF26A69A);

  static const List<Color> _segmentColorOptions = <Color>[
    Color(0xFF26A69A),
    Color(0xFF7C9EFF),
    Color(0xFFFFD54F),
    Color(0xFFEF5350),
    Color(0xFF8E24AA),
    Color(0xFF1DE9B6),
    Color(0xFFFF6D00),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFFFFA726),
    Color(0xFFEC407A),
    Color(0xFF4DD0E1),
  ];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    _weightCtrl.dispose();
    _imageCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickSegmentColor(PrizeSegment segment) async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text(
            'Choose segment color',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _segmentColorOptions
                  .map(
                    (option) => GestureDetector(
                      onTap: () => Navigator.of(context).pop(option),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: option,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: option == segment.color
                                ? Colors.white
                                : Colors.white24,
                            width: option == segment.color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected != null && selected != segment.color) {
      store.updateSegment(segment.id, segment.copyWith(color: selected));
    }
  }

  Widget? _buildLimitControls(PrizeSegment segment) {
    if (segment.isTryAgain) {
      return null;
    }

    final limitEnabled =
        (segment.winLimitCount ?? 0) > 0 && segment.winLimitPeriod != null;
    final remaining = limitEnabled
        ? store.remainingPrizeAllowance(segment, DateTime.now())
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Switch(
                value: limitEnabled,
                onChanged: (value) {
                  if (value) {
                    store.updateSegment(
                      segment.id,
                      segment.copyWith(
                        winLimitCount: segment.winLimitCount ?? 1,
                        winLimitPeriod:
                            segment.winLimitPeriod ?? PrizeLimitPeriod.week,
                      ),
                    );
                  } else {
                    store.updateSegment(
                      segment.id,
                      segment.copyWith(
                        winLimitCount: null,
                        winLimitPeriod: null,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Win limit',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.95 * 255).round()),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Control how many times this prize can be awarded.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (limitEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(
                      text: segment.winLimitCount?.toString() ?? '',
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Wins',
                      labelStyle:
                          TextStyle(color: Colors.white54, fontSize: 12),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                    ),
                    onSubmitted: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed <= 0) {
                        store.updateSegment(
                          segment.id,
                          segment.copyWith(
                            winLimitCount: null,
                            winLimitPeriod: null,
                          ),
                        );
                      } else {
                        store.updateSegment(
                          segment.id,
                          segment.copyWith(winLimitCount: parsed),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<PrizeLimitPeriod>(
                  value: segment.winLimitPeriod ?? PrizeLimitPeriod.week,
                  dropdownColor: Colors.black87,
                  underline: const SizedBox(),
                  items: PrizeLimitPeriod.values
                      .map(
                        (period) => DropdownMenuItem(
                          value: period,
                          child: Text(
                            period.label,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (period) {
                    if (period == null) {
                      return;
                    }
                    store.updateSegment(
                      segment.id,
                      segment.copyWith(winLimitPeriod: period),
                    );
                  },
                ),
                const Spacer(),
              ],
            ),
            if (remaining != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Remaining this ${segment.winLimitPeriod?.shortLabel ?? 'period'}: $remaining',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _addSegment() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    final weight = double.tryParse(_weightCtrl.text) ?? 1;
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    final seg = PrizeSegment(
      id: 'seg_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      type: _type,
      moneyAmount: _type == PrizeType.money ? amt : 0,
      itemName: _type == PrizeType.item ? label : null,
      image: _type == PrizeType.item
          ? (_imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim())
          : null,
      weight: weight.clamp(0.0, 100.0), // Allow 0-100 range
      color: _color,
    );
    store.addSegment(seg);
    _labelCtrl.clear();
    _amountCtrl.clear();
    _weightCtrl.text = '50'; // Default to 50% (medium chance)
    _imageCtrl.clear();
  }

  Widget _buildImage(String imagePath) {
    // Check if it's a network URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white),
      );
    }
    // Check if it's an asset path
    else if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported, color: Colors.white),
      );
    }
    // Otherwise, treat it as a file path from image picker
    else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image, color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: FloatingHeader(
            title: 'NGMY Store Admin',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
            bottom: FloatingTabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Wheel'),
                Tab(text: 'Betting'),
                Tab(text: 'Deposits'),
                Tab(text: 'Withdrawals'),
                Tab(text: 'Shipments'),
                Tab(text: 'Users'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildWheelTab(),
              _buildBettingTab(),
              _buildDepositsTab(),
              _buildWithdrawalsTab(),
              _buildShipmentsTab(),
              _buildUsersTab(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWheelTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User Search
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search user by ID...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (userId) {
                    if (userId.trim().isEmpty) return;
                    // User search functionality placeholder
                    // In a real app, this would query a database of users
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'User search not yet connected to database: $userId'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Wheel Segments', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        ...store.segments.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final limitControls = _buildLimitControls(s);
          return Card(
            key: ValueKey(s.id),
            color: Colors.white10,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Tooltip(
                        message: 'Tap to change segment color',
                        child: GestureDetector(
                          onTap: () => _pickSegmentColor(s),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.white38, width: 2),
                            ),
                            child: Stack(
                              children: [
                                if (s.type == PrizeType.item &&
                                    s.image != null &&
                                    s.image!.isNotEmpty)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: _buildImage(s.image!),
                                    ),
                                  ),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withAlpha((0.55 * 255).round()),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: TextEditingController(text: s.label),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                hintText: 'Label',
                                hintStyle: TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white24)),
                                enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white24)),
                              ),
                              onSubmitted: (v) {
                                final trimmed = v.trim();
                                final nextLabel =
                                    trimmed.isEmpty ? s.label : trimmed;
                                store.updateSegment(
                                  s.id,
                                  s.copyWith(
                                    label: nextLabel,
                                    itemName: s.type == PrizeType.item
                                        ? nextLabel
                                        : s.itemName,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.type == PrizeType.money
                                  ? 'Money Segment'
                                  : 'Item Segment',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => store.removeSegment(s.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (s.type == PrizeType.money) ...[
                    Row(
                      children: [
                        const Text('Amount: ₦₲',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: TextEditingController(
                              text: s.moneyAmount.toStringAsFixed(0),
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              border: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.white24)),
                              enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.white24)),
                            ),
                            onSubmitted: (v) {
                              final amt = double.tryParse(v) ?? s.moneyAmount;
                              store.updateSegment(
                                s.id,
                                s.copyWith(moneyAmount: amt),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (s.type == PrizeType.item) ...[
                    Row(
                      children: [
                        const Text('Item Image:',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 8),
                        if (s.image != null && s.image!.isNotEmpty)
                          Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: _buildImage(s.image!),
                            ),
                          ),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final image = await picker.pickImage(
                                  source: ImageSource.gallery);
                              if (image != null) {
                                store.updateSegment(
                                  s.id,
                                  s.copyWith(image: image.path),
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Image added!')),
                                  );
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                            ),
                            icon: const Icon(Icons.add_photo_alternate,
                                size: 18, color: Colors.white70),
                            label: Text(
                              s.image != null && s.image!.isNotEmpty
                                  ? 'Change Image'
                                  : 'Add from Gallery',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ),
                        if (s.image != null && s.image!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear,
                                size: 18, color: Colors.redAccent),
                            onPressed: () {
                              store.updateSegment(
                                s.id,
                                s.copyWith(image: null),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (limitControls != null) ...[
                    const SizedBox(height: 8),
                    limitControls,
                  ],
                  Row(
                    children: [
                      const Text('Chance %:',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: TextEditingController(
                              text: s.weight.toStringAsFixed(1)),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            hintText: '0-100',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24)),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24)),
                          ),
                          onSubmitted: (v) {
                            final w = (double.tryParse(v) ?? s.weight)
                                .clamp(0.0, 100.0);
                            store.setSegmentWeight(s.id, w);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.weight == 0
                              ? Colors.grey.withAlpha(100)
                              : s.weight >= 67
                                  ? Colors.green.withAlpha(100)
                                  : s.weight >= 34
                                      ? Colors.orange.withAlpha(100)
                                      : Colors.red.withAlpha(100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.weight == 0
                              ? 'Disabled'
                              : s.weight >= 67
                                  ? 'Very Likely'
                                  : s.weight >= 34
                                      ? 'Uncommon'
                                      : 'Rare',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            store.makeDominant(s.id, dominant: 95, others: 1),
                        child:
                            const Text('95%', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Divider(color: Colors.white24),
        const SizedBox(height: 12),
        const Text('Add Segment', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label / Item name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<PrizeType>(
              value: _type,
              dropdownColor: Colors.black,
              items: const [
                DropdownMenuItem(
                    value: PrizeType.money,
                    child:
                        Text('Money', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: PrizeType.item,
                    child: Text('Item', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _type = v ?? PrizeType.money),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_type == PrizeType.money) ...[
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal)),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      _imageCtrl.text = image.path;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Image selected!')),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                  ),
                  icon: const Icon(Icons.add_photo_alternate,
                      color: Colors.white70),
                  label: Text(
                    _imageCtrl.text.isEmpty
                        ? 'Add Item Image from Gallery'
                        : 'Image Selected',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              if (_imageCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                  onPressed: () => setState(() => _imageCtrl.clear()),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _weightCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Chance % (0=Never, 50=Medium, 100=Very High)',
            labelStyle: TextStyle(color: Colors.white70),
            hintText: '0-100',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white30)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: _addSegment,
              child: const Text('Add'),
            ),
            ElevatedButton(
              onPressed: () => store.resetTotals(),
              child: const Text('Reset Totals'),
            ),
            ElevatedButton(
              onPressed: store.normalizeWeightsTo100,
              child: const Text('Normalize to 100%'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Pending Item Wins',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        if (store.pendingItemWins.isEmpty)
          const Text('No pending items',
              style: TextStyle(color: Colors.white54))
        else
          ...store.pendingItemWins.map((w) => ListTile(
                tileColor: Colors.white10,
                leading: const Icon(Icons.inventory_2, color: Colors.white70),
                title: Text(w.itemName,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(w.userId,
                    style: const TextStyle(color: Colors.white70)),
                trailing: ElevatedButton(
                  onPressed:
                      w.fulfilled ? null : () => store.markItemFulfilled(w.id),
                  child: Text(w.fulfilled ? 'Fulfilled' : 'Mark Fulfilled'),
                ),
              )),
      ],
    );
  }

  Widget _buildBettingTab() {
    final betAmounts = store.betAmounts;
    final amountController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Betting Amount Controls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Add new bet amount
          Card(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Bet Amount',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Enter amount (e.g., 25)',
                            hintStyle: TextStyle(color: Colors.white54),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF00C853)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          final text = amountController.text.trim();
                          final amount = double.tryParse(text);
                          if (amount != null && amount > 0) {
                            store.addBetAmount(amount);
                            amountController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Added ₦₲${amount.toStringAsFixed(0)} to bet amounts'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid amount'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Amount'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Current bet amounts
          const Text(
            'Current Bet Amounts',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: betAmounts.isEmpty
                ? const Center(
                    child: Text(
                      'No bet amounts configured',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: betAmounts.length,
                    itemBuilder: (context, index) {
                      final amount = betAmounts[index];
                      return Card(
                        color: Colors.white.withAlpha((0.05 * 255).round()),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(
                            Icons.attach_money,
                            color: Color(0xFF00C853),
                          ),
                          title: Text(
                            '₦₲${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: IconButton(
                            onPressed: betAmounts.length > 1
                                ? () {
                                    store.removeBetAmount(amount);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Removed ₦₲${amount.toStringAsFixed(0)} from bet amounts'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: betAmounts.length > 1
                                ? 'Remove amount'
                                : 'Cannot remove (minimum 1 amount required)',
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

  Widget _buildDepositsTab() {
    final deposits = store.depositRequests;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (deposits.isEmpty)
          const Center(
              child: Text('No deposit requests',
                  style: TextStyle(color: Colors.white54)))
        else
          ...deposits.map((d) => Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.add_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('₦₲${d.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                Text('User: ${d.userId}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text('${d.timestamp}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                                // Show days until expiration
                                Text(
                                  'Expires in: ${3 - DateTime.now().difference(d.timestamp).inDays} days',
                                  style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: d.status == RequestStatus.pending
                                  ? Colors.orange
                                  : d.status == RequestStatus.approved
                                      ? Colors.green
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              d.status.name.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Screenshot viewer button
                      OutlinedButton.icon(
                        onPressed: () => _viewDepositScreenshot(d),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const Icon(Icons.image, color: Colors.white70),
                        label: const Text('View Screenshot',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      // Show admin comment if exists
                      if (d.adminComment != null &&
                          d.adminComment!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueAccent),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admin Comment:',
                                  style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(d.adminComment!,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                      if (d.status == RequestStatus.pending) ...[
                        const SizedBox(height: 12),
                        // Comment button
                        OutlinedButton.icon(
                          onPressed: () => _addDepositComment(d),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blueAccent),
                          ),
                          icon: const Icon(Icons.comment,
                              color: Colors.blueAccent),
                          label: Text(
                            d.adminComment == null
                                ? 'Add Comment'
                                : 'Edit Comment',
                            style: const TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => store.updateDepositStatus(
                                    d.id, RequestStatus.approved),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                child: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => store.updateDepositStatus(
                                    d.id, RequestStatus.rejected),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildWithdrawalsTab() {
    final withdrawals = store.withdrawRequests;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (withdrawals.isEmpty)
          const Center(
              child: Text('No withdrawal requests',
                  style: TextStyle(color: Colors.white54)))
        else
          ...withdrawals.map((w) => Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.remove_circle, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('₦₲${w.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                Text('User: ${w.userId}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text('${w.timestamp}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: w.status == RequestStatus.pending
                                  ? Colors.orange
                                  : w.status == RequestStatus.approved
                                      ? Colors.green
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              w.status.name.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Cash App: \$${w.cashAppTag}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      if (w.status == RequestStatus.pending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => store.updateWithdrawStatus(
                                    w.id, RequestStatus.approved),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                child: const Text('Approve & Send'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => store.updateWithdrawStatus(
                                    w.id, RequestStatus.rejected),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildShipmentsTab() {
    final shipments = store.shipmentRequests;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (shipments.isEmpty)
          const Center(
              child: Text('No shipment requests',
                  style: TextStyle(color: Colors.white54)))
        else
          ...shipments.map((s) => Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.itemName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                Text('User: ${s.userId}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text('${s.timestamp}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: s.status == RequestStatus.pending
                                  ? Colors.orange
                                  : s.status == RequestStatus.approved
                                      ? Colors.green
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              s.status.name.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x0DFFFFFF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.fullName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(s.address,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            Text('${s.city}, ${s.zipCode}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (s.status == RequestStatus.pending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => store.updateShipmentStatus(
                                    s.id, RequestStatus.approved),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                child: const Text('Mark Shipped'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => store.updateShipmentStatus(
                                    s.id, RequestStatus.rejected),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  void _viewDepositScreenshot(DepositRequest deposit) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Deposit Screenshot - ₦₲${deposit.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: deposit.screenshotPath.isNotEmpty
                    ? _buildImage(deposit.screenshotPath)
                    : const Center(
                        child:
                            Icon(Icons.image, color: Colors.white54, size: 64),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Pinch to zoom • Drag to pan',
                style: TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _addDepositComment(DepositRequest deposit) {
    final commentController =
        TextEditingController(text: deposit.adminComment ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text('Admin Comment', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: commentController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Add a comment for the user...',
            hintStyle: const TextStyle(color: Colors.white54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              store.addDepositComment(deposit.id, commentController.text);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comment saved')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Save Comment'),
          ),
        ],
      ),
    );
  }

  // ========== USERS TAB ==========
  Widget _buildUsersTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.black,
            child: const TabBar(
              indicatorColor: Color(0xFF00E5A8),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'Top Winners'),
                Tab(text: 'Top Losers'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildWinnersTab(),
                _buildLosersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnersTab() {
    // Calculate user statistics from spin history
    final userStats = _calculateUserStats();

    // Sort by total money won (descending)
    final winners = userStats.entries.toList()
      ..sort((a, b) => b.value['totalWon'].compareTo(a.value['totalWon']));

    if (winners.isEmpty) {
      return const Center(
        child: Text(
          'No spin history yet',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: winners.length,
      itemBuilder: (context, index) {
        final username = winners[index].key;
        final stats = winners[index].value;
        final rank = index + 1;

        return _buildUserStatCard(
          rank: rank,
          username: username,
          totalGames: stats['totalGames'] as int,
          totalMoneySpent: stats['totalMoneySpent'] as double,
          totalWins: stats['totalWins'] as int,
          totalLosses: stats['totalLosses'] as int,
          totalWon: stats['totalWon'] as double,
          totalLost: stats['totalLost'] as double,
          isWinner: true,
        );
      },
    );
  }

  Widget _buildLosersTab() {
    // Calculate user statistics from spin history
    final userStats = _calculateUserStats();

    // Sort by total money lost (descending - most lost at top)
    final losers = userStats.entries.toList()
      ..sort((a, b) => b.value['totalLost'].compareTo(a.value['totalLost']));

    if (losers.isEmpty) {
      return const Center(
        child: Text(
          'No spin history yet',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: losers.length,
      itemBuilder: (context, index) {
        final username = losers[index].key;
        final stats = losers[index].value;
        final rank = index + 1;

        return _buildUserStatCard(
          rank: rank,
          username: username,
          totalGames: stats['totalGames'] as int,
          totalMoneySpent: stats['totalMoneySpent'] as double,
          totalWins: stats['totalWins'] as int,
          totalLosses: stats['totalLosses'] as int,
          totalWon: stats['totalWon'] as double,
          totalLost: stats['totalLost'] as double,
          isWinner: false,
        );
      },
    );
  }

  Map<String, Map<String, dynamic>> _calculateUserStats() {
    final stats = <String, Map<String, dynamic>>{};

    for (final spin in store.spinHistory) {
      if (!stats.containsKey(spin.username)) {
        stats[spin.username] = {
          'totalGames': 0,
          'totalMoneySpent': 0.0,
          'totalWins': 0,
          'totalLosses': 0,
          'totalWon': 0.0,
          'totalLost': 0.0,
        };
      }

      stats[spin.username]!['totalGames']++;
      stats[spin.username]!['totalMoneySpent'] += spin.betAmount;

      if (spin.isWin) {
        stats[spin.username]!['totalWins']++;
        stats[spin.username]!['totalWon'] += spin.moneyAmount;
      } else {
        stats[spin.username]!['totalLosses']++;
        stats[spin.username]!['totalLost'] += spin.moneyAmount.abs();
      }
    }

    return stats;
  }

  Widget _buildUserStatCard({
    required int rank,
    required String username,
    required int totalGames,
    required double totalMoneySpent,
    required int totalWins,
    required int totalLosses,
    required double totalWon,
    required double totalLost,
    required bool isWinner,
  }) {
    Color rankColor;
    IconData rankIcon;

    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.workspace_premium;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.military_tech;
    } else {
      rankColor = Colors.white54;
      rankIcon = Icons.person;
    }

    final netProfit = totalWon - totalLost;
    final winRate = totalGames > 0 ? (totalWins / totalGames * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isWinner ? Colors.green : Colors.red)
                .withAlpha((0.15 * 255).round()),
            Colors.white.withAlpha((0.05 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isWinner ? Colors.green : Colors.red)
              .withAlpha((0.3 * 255).round()),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rankColor.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(rankIcon, color: rankColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$rank',
                          style: TextStyle(
                            color: rankColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalGames games played • ${winRate.toStringAsFixed(1)}% win rate',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: netProfit >= 0
                        ? [Colors.green.shade700, Colors.green.shade900]
                        : [Colors.red.shade700, Colors.red.shade900],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${netProfit >= 0 ? '+' : ''}₦₲${netProfit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildStatRow(
                  icon: Icons.attach_money,
                  label: 'Total Spent',
                  value: '₦₲${totalMoneySpent.toStringAsFixed(2)}',
                  color: Colors.orange,
                ),
                const Divider(color: Colors.white24, height: 16),
                _buildStatRow(
                  icon: Icons.trending_up,
                  label: 'Wins',
                  value: '$totalWins • ₦₲${totalWon.toStringAsFixed(2)}',
                  color: Colors.green,
                ),
                const Divider(color: Colors.white24, height: 16),
                _buildStatRow(
                  icon: Icons.trending_down,
                  label: 'Losses',
                  value: '$totalLosses • ₦₲${totalLost.toStringAsFixed(2)}',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.7 * 255).round()),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
