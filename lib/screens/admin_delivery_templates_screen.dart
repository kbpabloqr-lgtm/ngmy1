import 'package:flutter/material.dart';

import '../models/delivery_guideline_models.dart';
import '../services/delivery_guideline_store.dart';

typedef DeliveryTemplateEditHandler = Future<void> Function(
  String fieldLabel,
  String initialValue,
  ValueChanged<String> onSubmit,
);

class AdminDeliveryTemplatesScreen extends StatefulWidget {
  const AdminDeliveryTemplatesScreen({super.key});

  @override
  State<AdminDeliveryTemplatesScreen> createState() =>
      _AdminDeliveryTemplatesScreenState();
}

class _AdminDeliveryTemplatesScreenState
    extends State<AdminDeliveryTemplatesScreen> {
  final DeliveryGuidelineStore _store = DeliveryGuidelineStore.instance;
  final PageController _pageController = PageController();

  bool _loading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    await _store.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _currentPage = 0;
    });
  }

  void _handleStoreChanged() {
    if (!mounted) return;
    final scenarios = _store.scenarios;
    final clampedIndex = scenarios.isEmpty
        ? 0
        : _currentPage.clamp(0, scenarios.length - 1);
    setState(() {
      _currentPage = clampedIndex;
    });
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editField(
    String label,
    String initialValue,
    ValueChanged<String> onSubmit,
  ) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(
            'Edit $label',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new value',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent),
              ),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
            textInputAction: TextInputAction.done,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed == initialValue) {
      return;
    }

    onSubmit(trimmed);
  }

  void _updateScenario(DeliveryScenarioData updated) {
    _store.updateScenario(updated);
  }

  Future<void> _resetToDefaults() async {
    await _store.resetToDefaults();
    if (!mounted) return;
    setState(() {
      _currentPage = 0;
    });
    _pageController.jumpToPage(0);
  }

  void _handlePrimaryAction(DeliveryScenarioData scenario) {
    final scenarios = _store.scenarios;
    final index = scenarios.indexWhere((s) => s.id == scenario.id);
    if (index == -1) {
      return;
    }

    if (index < scenarios.length - 1) {
      setState(() {
        _currentPage = index + 1;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have reached the last delivery template.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _updateInfoTile(
    DeliveryScenarioData scenario,
    int tileIndex,
    DeliveryInfoTile updated,
  ) {
    final tiles = List<DeliveryInfoTile>.from(scenario.infoTiles);
    if (tileIndex < 0 || tileIndex >= tiles.length) {
      return;
    }
    tiles[tileIndex] = updated;
    _updateScenario(scenario.copyWith(infoTiles: tiles));
  }

  @override
  Widget build(BuildContext context) {
    final scenarios = _store.scenarios;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : scenarios.isEmpty
                ? const Center(
                    child: Text('No delivery templates configured.'),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: scenarios.length,
                          itemBuilder: (context, index) {
                            final scenario = scenarios[index];
                            if (scenario.layout == 'reminder') {
                              return _ReminderScenarioView(
                                scenario: scenario,
                                onEdit: _editField,
                                onChanged: _updateScenario,
                                onRequestReset: _resetToDefaults,
                              );
                            }
                            return _PickupScenarioView(
                              scenario: scenario,
                              onEdit: _editField,
                              onChanged: _updateScenario,
                              onInfoTileChanged: _updateInfoTile,
                              onRequestReset: _resetToDefaults,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PageIndicator(
                        pageCount: scenarios.length,
                        currentIndex: _currentPage,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                        child: _PrimaryGradientButton(
                          label: scenarios[_currentPage].primaryButtonLabel,
                          onPressed: () =>
                              _handlePrimaryAction(scenarios[_currentPage]),
                        ),
                      ),
                      Container(
                        width: 120,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _PickupScenarioView extends StatelessWidget {
  const _PickupScenarioView({
    required this.scenario,
    required this.onEdit,
    required this.onChanged,
    required this.onInfoTileChanged,
    required this.onRequestReset,
  });

  final DeliveryScenarioData scenario;
  final DeliveryTemplateEditHandler onEdit;
  final ValueChanged<DeliveryScenarioData> onChanged;
  final void Function(DeliveryScenarioData scenario, int index,
      DeliveryInfoTile updated) onInfoTileChanged;
  final VoidCallback onRequestReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F6F6),
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOrderCard(context),
                  if (scenario.bannerTitle != null ||
                      scenario.bannerBody != null) ...[
                    const SizedBox(height: 16),
                    _buildBanner(context),
                  ],
                  if (scenario.infoTiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInfoTiles(context),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.menu_rounded, color: Color(0xFF111827)),
          Expanded(
            child: _editableText(
              context,
              label: 'Pickup time',
              value: scenario.deliverBy,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
              onChanged: (value) =>
                  onChanged(scenario.copyWith(deliverBy: value)),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: onRequestReset,
            child: const Text(
              'Help',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _editableText(
                      context,
                      label: 'Order label',
                      value: scenario.deliveryForLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                      onChanged: (value) => onChanged(
                        scenario.copyWith(deliveryForLabel: value),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _editableText(
                      context,
                      label: 'Customer name',
                      value: scenario.customerName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      onChanged: (value) =>
                          onChanged(scenario.copyWith(customerName: value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: const [
                  _ActionCircleIcon(icon: Icons.call),
                  SizedBox(height: 12),
                  _ActionCircleIcon(icon: Icons.chat_bubble_outline),
                ],
              ),
            ],
          ),
          if (scenario.merchantButtonLabel != null) ...[
            const SizedBox(height: 16),
            _editablePill(
              context,
              label: 'Merchant button',
              value: scenario.merchantButtonLabel!,
              onChanged: (value) => onChanged(
                scenario.copyWith(merchantButtonLabel: value),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ActionCircleIcon(icon: Icons.inventory_2_outlined),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _editableText(
                      context,
                      label: 'Equipment title',
                      value: scenario.instructionTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      onChanged: (value) => onChanged(
                        scenario.copyWith(instructionTitle: value),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _editableText(
                      context,
                      label: 'Equipment body',
                      value: scenario.instructionBody,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                      onChanged: (value) => onChanged(
                        scenario.copyWith(instructionBody: value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (scenario.equipmentPrimaryAction != null) ...[
            const SizedBox(height: 20),
            _editableGradientButton(
              context,
              label: 'Primary equipment action',
              value: scenario.equipmentPrimaryAction!,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFEF4444)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              onChanged: (value) => onChanged(
                scenario.copyWith(equipmentPrimaryAction: value),
              ),
            ),
          ],
          if (scenario.equipmentSecondaryAction != null) ...[
            const SizedBox(height: 14),
            _editableText(
              context,
              label: 'Secondary equipment action',
              value: scenario.equipmentSecondaryAction!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
              textAlign: TextAlign.center,
              onChanged: (value) => onChanged(
                scenario.copyWith(equipmentSecondaryAction: value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scenario.bannerTitle != null)
            _editableText(
              context,
              label: 'Banner title',
              value: scenario.bannerTitle!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
              ),
              onChanged: (value) =>
                  onChanged(scenario.copyWith(bannerTitle: value)),
            ),
          if (scenario.bannerBody != null) ...[
            const SizedBox(height: 6),
            _editableText(
              context,
              label: 'Banner body',
              value: scenario.bannerBody!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7F1D1D),
                height: 1.4,
              ),
              onChanged: (value) =>
                  onChanged(scenario.copyWith(bannerBody: value)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTiles(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < scenario.infoTiles.length; index++)
            Column(
              children: [
                _InfoTileRow(
                  tile: scenario.infoTiles[index],
                  onEdit: onEdit,
                  onChanged: (updated) =>
                      onInfoTileChanged(scenario, index, updated),
                ),
                if (index != scenario.infoTiles.length - 1)
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _editableText(
    BuildContext context, {
    required String label,
    required String value,
    required TextStyle style,
    required ValueChanged<String> onChanged,
    TextAlign textAlign = TextAlign.start,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => onEdit(label, value, onChanged),
      child: Text(
        value,
        style: style,
        textAlign: textAlign,
      ),
    );
  }

  Widget _editablePill(
    BuildContext context, {
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => onEdit(label, value, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _editableGradientButton(
    BuildContext context, {
    required String label,
    required String value,
    required TextStyle textStyle,
    required LinearGradient gradient,
    required ValueChanged<String> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => onEdit(label, value, onChanged),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(value, style: textStyle),
      ),
    );
  }
}

class _ReminderScenarioView extends StatelessWidget {
  const _ReminderScenarioView({
    required this.scenario,
    required this.onEdit,
    required this.onChanged,
    required this.onRequestReset,
  });

  final DeliveryScenarioData scenario;
  final DeliveryTemplateEditHandler onEdit;
  final ValueChanged<DeliveryScenarioData> onChanged;
  final VoidCallback onRequestReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F6F6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: onRequestReset,
                  child: const Icon(Icons.close, color: Color(0xFF111827)),
                ),
                const Icon(Icons.help_outline, color: Color(0xFFE2E8F0)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F1),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: const Icon(
                      Icons.delivery_dining,
                      color: Color(0xFFEF4444),
                      size: 82,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (scenario.bannerTitle != null)
                    _editableText(
                      context,
                      label: 'Reminder title',
                      value: scenario.bannerTitle!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          onChanged(scenario.copyWith(bannerTitle: value)),
                    ),
                  if (scenario.bannerBody != null) ...[
                    const SizedBox(height: 18),
                    _editableText(
                      context,
                      label: 'Reminder body',
                      value: scenario.bannerBody!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          onChanged(scenario.copyWith(bannerBody: value)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableText(
    BuildContext context, {
    required String label,
    required String value,
    required TextStyle style,
    required ValueChanged<String> onChanged,
    TextAlign textAlign = TextAlign.start,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => onEdit(label, value, onChanged),
      child: Text(
        value,
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

class _InfoTileRow extends StatelessWidget {
  const _InfoTileRow({
    required this.tile,
    required this.onEdit,
    required this.onChanged,
  });

  final DeliveryInfoTile tile;
  final DeliveryTemplateEditHandler onEdit;
  final ValueChanged<DeliveryInfoTile> onChanged;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForTile(tile);
    final bool showCallButton = _shouldShowCallButton(tile);
    final bool showDisclosure = _shouldShowDisclosure(tile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconData,
              color: const Color(0xFF111827),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () => onEdit(
                    'Tile title',
                    tile.title,
                    (value) => onChanged(tile.copyWith(title: value)),
                  ),
                  child: Text(
                    tile.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (tile.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPress: () => onEdit(
                      'Tile body',
                      tile.body,
                      (value) => onChanged(tile.copyWith(body: value)),
                    ),
                    child: Text(
                      tile.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showCallButton)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.call, color: Color(0xFF111827), size: 18),
            )
          else if (showDisclosure)
            const Icon(Icons.expand_more, color: Color(0xFF6B7280)),
        ],
      ),
    );
  }

  IconData _iconForTile(DeliveryInfoTile tile) {
    final title = tile.title.toLowerCase();
    if (title.contains('item')) {
      return Icons.receipt_long;
    }
    if (title.contains('walk') || title.contains('enter')) {
      return Icons.directions_walk;
    }
    if (title.contains('shelf') || title.contains('pickup')) {
      return Icons.inventory_2_outlined;
    }
    if (title.contains('help') || title.contains('support')) {
      return Icons.headset_mic_outlined;
    }
    return Icons.place;
  }

  bool _shouldShowCallButton(DeliveryInfoTile tile) {
    final title = tile.title.toLowerCase();
    return title.contains('help') || title.contains('support');
  }

  bool _shouldShowDisclosure(DeliveryInfoTile tile) {
    final title = tile.title.toLowerCase();
    return title.contains('walk') || title.contains('pickup');
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(pageCount, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 10,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFEF4444)
                : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ActionCircleIcon extends StatelessWidget {
  const _ActionCircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: const Color(0xFF111827)),
    );
  }
}
