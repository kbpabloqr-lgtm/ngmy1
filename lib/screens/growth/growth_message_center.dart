import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ngmy1/models/growth_chat_models.dart';
import 'package:ngmy1/services/growth_messaging_store.dart';
import 'package:ngmy1/services/growth_user_directory.dart';
import 'package:ngmy1/services/user_account_service.dart';
import 'package:ngmy1/screens/global/global_notifications_screen.dart';
import 'package:ngmy1/screens/growth_notifications_screen.dart';

const Color _studioBackground = Color(0xFF050915);
const Color _studioAccent = Color(0xFF0DF5E3);
const Color _studioAccentSecondary = Color(0xFF8C6CFF);

class _StudioAppBar extends StatelessWidget {
  const _StudioAppBar({
    required this.label,
    required this.isAdmin,
    this.onNotifications,
    this.onBroadcast,
    this.onPermissions,
  });

  final String label;
  final bool isAdmin;
  final VoidCallback? onNotifications;
  final VoidCallback? onBroadcast;
  final VoidCallback? onPermissions;

  @override
  Widget build(BuildContext context) {
    final String subline = isAdmin
        ? 'Admin lane active • Keep the studio momentum smooth.'
        : 'Tap notifications to catch up across every studio lane.';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x661B2A4C), Color(0x440C152A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withAlpha((0.08 * 255).round()),
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subline,
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.68 * 255).round()),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (onBroadcast != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _CircularIconButton(
                    icon: Icons.wifi_tethering,
                    tooltip: 'Broadcast update',
                    onPressed: onBroadcast,
                    foregroundColor: Colors.black,
                    gradientColors: [
                      _studioAccentSecondary,
                      _studioAccentSecondary.withAlpha((0.6 * 255).round()),
                    ],
                  ),
                ),
              if (onPermissions != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _CircularIconButton(
                    icon: Icons.rule_folder_outlined,
                    tooltip: 'Manage permissions',
                    onPressed: onPermissions,
                    gradientColors: [
                      const Color(0xFF3A4EF0),
                      const Color(0xFF2838C8),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _CircularIconButton(
                  icon: Icons.notifications_none,
                  tooltip: 'Studio notifications',
                  onPressed: onNotifications,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  const _CircularIconButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.foregroundColor,
    this.gradientColors,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? foregroundColor;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = gradientColors ?? [
      Colors.white.withAlpha((0.18 * 255).round()),
      Colors.white.withAlpha((0.05 * 255).round()),
    ];

    final Widget button = Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withAlpha((0.16 * 255).round()),
              ),
              boxShadow: onPressed == null
                  ? const []
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.45 * 255).round()),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Icon(
              icon,
              color: foregroundColor ?? Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(
      message: tooltip!,
      child: button,
    );
  }
}
class GrowthMessagingScreen extends StatefulWidget {
  const GrowthMessagingScreen({
    super.key,
    required this.scope,
    this.adminMode = false,
  });

  final GrowthChatScope scope;
  final bool adminMode;

  @override
  State<GrowthMessagingScreen> createState() => _GrowthMessagingScreenState();
}
class _StudioOverviewHeader extends StatelessWidget {
  const _StudioOverviewHeader({
    required this.scope,
    required this.isAdmin,
    required this.currentUser,
    required this.unreadCount,
    required this.threadCount,
    required this.lockedThreads,
    required this.memberCount,
    this.onCompose,
    this.onBroadcast,
    this.onPermissions,
  });

  final GrowthChatScope scope;
  final bool isAdmin;
  final UserAccount currentUser;
  final int unreadCount;
  final int threadCount;
  final int lockedThreads;
  final int memberCount;
  final VoidCallback? onCompose;
  final VoidCallback? onBroadcast;
  final VoidCallback? onPermissions;

  @override
  Widget build(BuildContext context) {
    final String studioLabel = scope.studioLabel;
    final String firstName = currentUser.name.isNotEmpty
        ? currentUser.name.split(' ').first
        : 'Studio Member';

    final int momentumSeed = math
        .min(threadCount * 2 + unreadCount + (isAdmin ? 6 : 0), 40);
    final double momentumProgress = momentumSeed / 40.0;
    final int momentumPercent = (momentumProgress * 100).round();
    final String momentumLabel = momentumPercent >= 70
        ? 'Studio vibe is electric'
        : momentumPercent >= 40
            ? 'Studio is warming up'
            : 'Ready for fresh energy';

    final Widget avatar = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF0DF5E3), Color(0xFF00A2F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withAlpha((0.24 * 255).round()),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Text(
          currentUser.name.isNotEmpty
              ? currentUser.name[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    final List<Widget> quickActions = <Widget>[
      if (onCompose != null)
        _StudioQuickActionTile(
          icon: Icons.add_comment_outlined,
          label: 'Start Chat',
          subtitle: 'Open a fresh studio thread',
          color: _studioAccent,
          foreground: Colors.black,
          onTap: onCompose!,
        ),
      if (onBroadcast != null)
        _StudioQuickActionTile(
          icon: Icons.podcasts,
          label: 'Broadcast',
          subtitle: 'One update for everyone',
          color: _studioAccentSecondary,
          onTap: onBroadcast!,
        ),
      if (onPermissions != null)
        _StudioQuickActionTile(
          icon: Icons.rule_folder_outlined,
          label: 'Permissions',
          subtitle: 'Curate studio access',
          color: const Color(0xFF5C6BFF),
          onTap: onPermissions!,
        ),
    ];

    final List<Widget> statChips = <Widget>[
      _StatChip(
        label: 'Community',
        value: '$memberCount',
        color: Colors.lightBlueAccent.withAlpha((0.42 * 255).round()),
        icon: Icons.groups_rounded,
      ),
      _StatChip(
        label: 'Threads',
        value: '$threadCount',
        color: _studioAccent.withAlpha((0.48 * 255).round()),
        icon: Icons.hub_outlined,
      ),
      _StatChip(
        label: 'Unread',
        value: unreadCount > 99 ? '99+' : '$unreadCount',
        color: _studioAccentSecondary.withAlpha((0.48 * 255).round()),
        icon: Icons.mark_email_unread_outlined,
      ),
      if (lockedThreads > 0)
        _StatChip(
          label: 'Locked',
          value: '$lockedThreads',
          color: Colors.orangeAccent.withAlpha((0.43 * 255).round()),
          icon: Icons.lock_clock_outlined,
        ),
    ];

    final String statusPrimary = unreadCount == 0
        ? 'Studio is calm right now.'
        : '$unreadCount thread${unreadCount == 1 ? '' : 's'} need attention.';
    final String statusSecondary = lockedThreads > 0
        ? '$lockedThreads locked lane${lockedThreads == 1 ? '' : 's'}'
        : 'All lanes open';

    final List<Widget> infoFrames = <Widget>[
      _StudioStatusFrame(
        title: '${scope.shortLabel} studio status',
        primary: statusPrimary,
        secondary: statusSecondary,
      ),
      _StudioBroadcastFrame(
        title: scope.broadcastTitle,
        description: isAdmin
            ? 'Share a pulse or celebrate a win with everyone.'
            : 'Stay tuned for studio-wide updates and recaps.',
        onBroadcast: onBroadcast,
      ),
    ];

    final bool hasQuickActions = quickActions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studioLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin
                          ? 'Guide the energy and spotlight the wins.'
                          : 'Welcome back $firstName. Your studio pulse is ready.',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: momentumProgress.clamp(0.0, 1.0),
                        backgroundColor:
                            Colors.white.withAlpha((0.08 * 255).round()),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _studioAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Studio momentum $momentumPercent% • $momentumLabel',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.65 * 255).round()),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: statChips,
          ),
          if (hasQuickActions) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: quickActions,
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: infoFrames,
          ),
        ],
      ),
    );
  }
}

class _StudioStatusFrame extends StatelessWidget {
  const _StudioStatusFrame({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0x44203A6C), Color(0x33101F3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withAlpha((0.14 * 255).round()),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 22,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _studioAccent.withAlpha((0.28 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.self_improvement,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            primary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            secondary,
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioBroadcastFrame extends StatelessWidget {
  const _StudioBroadcastFrame({
    required this.title,
    required this.description,
    this.onBroadcast,
  });

  final String title;
  final String description;
  final VoidCallback? onBroadcast;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0x33203A6C), Color(0x22101F3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _studioAccentSecondary,
                      _studioAccentSecondary
                          .withAlpha((0.4 * 255).round()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.wifi_tethering,
                  color: Colors.black,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (onBroadcast != null)
                _CircularIconButton(
                  icon: Icons.open_in_new,
                  tooltip: 'Open broadcast lane',
                  onPressed: onBroadcast,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withAlpha((0.76 * 255).round()),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color baseColor =
        color ?? Colors.white.withAlpha((0.14 * 255).round());
    final Color gradientTail =
        Color.lerp(baseColor, Colors.black, 0.35)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, gradientTail],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withAlpha((0.12 * 255).round()),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: Colors.white.withAlpha((0.86 * 255).round()),
              size: 16,
            ),
            const SizedBox(width: 10),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withAlpha((0.62 * 255).round()),
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudioQuickActionTile extends StatelessWidget {
  const _StudioQuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.subtitle,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final Color? foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color start = color.withAlpha((0.55 * 255).round());
    final Color end = Color.lerp(start, Colors.black, 0.35)!;
    final Color textColor = foreground ?? Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [start, end],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withAlpha((0.16 * 255).round()),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 22,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.16 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 18, color: textColor),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: textColor.withAlpha((0.78 * 255).round()),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color background =
        color ?? Colors.white.withAlpha((0.12 * 255).round());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withAlpha((0.75 * 255).round()),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha((0.75 * 255).round()),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.currentUserId,
    required this.store,
    this.onTap,
  });

  final GrowthChatThread thread;
  final String currentUserId;
  final GrowthMessagingStore store;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final last = thread.messages.isNotEmpty ? thread.messages.last : null;
    final preview = last == null
        ? 'No messages yet'
        : last.type == GrowthChatMessageType.image
            ? '${last.senderName}: shared an image'
            : '${last.senderName}: ${last.content}';
    final updatedLabel = _formatRelativeTimeStatic(thread.updatedAt);
    final participantLabel = thread.isBroadcast
        ? 'Broadcast'
        : thread.isGroup
            ? '${thread.participants.length} members'
            : _directPartnerNameStatic(thread, currentUserId);
    final unread = store.unreadCountForThread(currentUserId, thread.id);
    final icon = thread.isBroadcast
        ? Icons.wifi_tethering
        : thread.isGroup
            ? Icons.people_alt_outlined
            : Icons.person_outline;
    final accent =
        thread.isBroadcast ? _studioAccentSecondary : _studioAccent;
    final bool timeLocked = thread.lockedUntil != null &&
        thread.lockedUntil!.isAfter(DateTime.now());
    final bool isLocked = thread.isLocked || timeLocked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0x44203A6C), Color(0x44101F3D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withAlpha((0.12 * 255).round()),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 26,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              accent.withAlpha((0.8 * 255).round()),
                              accent.withAlpha((0.28 * 255).round()),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color:
                              thread.isBroadcast ? Colors.black : Colors.black87,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    thread.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                Text(
                                  updatedLabel,
                                  style: TextStyle(
                                    color: Colors.white
                                        .withAlpha((0.62 * 255).round()),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _MetaPill(
                                  icon: icon,
                                  label: participantLabel,
                                  color: Colors.white
                                      .withAlpha((0.12 * 255).round()),
                                ),
                                if (thread.isBroadcast)
                                  _MetaPill(
                                    icon: Icons.podcasts,
                                    label: 'Broadcast lane',
                                    color: _studioAccentSecondary
                                        .withAlpha((0.3 * 255).round()),
                                  ),
                                if (isLocked)
                                  _MetaPill(
                                    icon: Icons.lock_outline,
                                    label: 'Locked',
                                    color: Colors.orangeAccent
                                        .withAlpha((0.35 * 255).round()),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -10,
              left: 32,
              right: 32,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      accent.withAlpha((0.2 * 255).round()),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -18,
                right: 24,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _studioAccent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _directPartnerNameStatic(
    GrowthChatThread thread,
    String currentUserId,
  ) {
    final partner = thread.participants.firstWhere(
      (participant) => participant.userId != currentUserId,
      orElse: () => thread.participants.first,
    );
    return partner.displayName;
  }

  static String _formatRelativeTimeStatic(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${dateTime.month}/${dateTime.day}';
  }
}

class _GrowthMessagingScreenState extends State<GrowthMessagingScreen> {
  final GrowthMessagingStore _store = GrowthMessagingStore.instance;
  UserAccount? _currentUser;
  bool _initializing = true;
  List<UserAccount> _allUsers = <UserAccount>[];

  bool get _isAdmin => widget.adminMode;

  bool _hasLegacyNotifications(GrowthChatScope scope) {
    return scope == GrowthChatScope.global || scope == GrowthChatScope.growth;
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _openNotificationCenter() {
    if (widget.scope == GrowthChatScope.global) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GlobalNotificationsScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GrowthNotificationsScreen()),
      );
    }
  }

  Future<void> _boot() async {
    await UserAccountService.instance.initialize();
    final user = UserAccountService.instance.currentUser;
    final users = await UserAccountService.instance.getAllUsers();
    await _store.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = user;
      _allUsers = users;
      _initializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
  final scopeLabel = widget.scope.studioLabel;

    return Scaffold(
      backgroundColor: _studioBackground,
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(104),
        child: _StudioAppBar(
          label: scopeLabel,
          isAdmin: _isAdmin,
      onNotifications: _hasLegacyNotifications(widget.scope)
        ? _openNotificationCenter
        : null,
          onBroadcast: _isAdmin ? _openBroadcastThread : null,
          onPermissions: _isAdmin ? _showPermissionSheet : null,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF050915),
              Color(0xFF091632),
            ],
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          top: true,
          child: _initializing
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        ),
      ),
    );
  }

  bool get _shouldShowComposerButton {
    final user = _currentUser;
    if (user == null) {
      return false;
    }
    if (_isAdmin) {
      return true;
    }
    return _store.canUserCreateGroup(user.id);
  }

  Widget _buildBody() {
    final user = _currentUser;
    if (user == null) {
      return _buildNoAccountPlaceholder();
    }

    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final allThreads = _store.threadsForScope(widget.scope);
        final threads = _isAdmin
            ? allThreads
            : _store.threadsForUser(user.id, widget.scope);
        final unreadTotal = _store.totalUnreadForScope(user.id, widget.scope);
        final lockedThreads = threads.where(_threadAppearsLocked).length;
        final memberIds = <String>{};
        for (final thread in allThreads) {
          for (final participant in thread.participants) {
            memberIds.add(participant.userId);
          }
        }
        final memberCount = memberIds.length;
        final bottomInset = MediaQuery.of(context).padding.bottom;
        final double scrollBottomPadding =
            bottomInset + (_shouldShowComposerButton ? 120 : 80);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _StudioOverviewHeader(
                scope: widget.scope,
                isAdmin: _isAdmin,
                currentUser: user,
                unreadCount: unreadTotal,
                threadCount: threads.length,
                lockedThreads: lockedThreads,
                memberCount: memberCount,
                onCompose: _shouldShowComposerButton
                    ? _openConversationComposer
                    : null,
                onBroadcast: _isAdmin ? _openBroadcastThread : null,
                onPermissions: _isAdmin ? _showPermissionSheet : null,
              ),
            ),
            if (threads.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, scrollBottomPadding),
                  child: _buildEmptyState(),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, scrollBottomPadding),
                sliver: SliverList.separated(
                  itemCount: threads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    return _ThreadCard(
                      thread: thread,
                      currentUserId: user.id,
                      store: _store,
                      onTap: () => _openThread(thread.id),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        );
      },
    );
  }

  bool _threadAppearsLocked(GrowthChatThread t) {
    final until = t.lockedUntil;
    if (until != null && until.isAfter(DateTime.now())) return true;
    return t.isLocked;
  }

  Widget _buildNoAccountPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _studioAccent.withAlpha((0.68 * 255).round()),
                    _studioAccent.withAlpha((0.24 * 255).round()),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.person_search,
                color: Colors.black,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sign in to access the Growth messaging studio.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Once you log in you can see threads, broadcasts, and start a new studio chat.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.72 * 255).round()),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 36),
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0x33203A6C), Color(0x33101F3D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withAlpha((0.12 * 255).round()),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 24,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _studioAccent.withAlpha((0.68 * 255).round()),
                    _studioAccent.withAlpha((0.24 * 255).round()),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.black,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'The studio is calm right now.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _shouldShowComposerButton
                  ? 'Tap New Studio Chat to launch the next momentum boost.'
                  : 'Share your studio ID with an admin to join the next storyline.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.7 * 255).round()),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (_shouldShowComposerButton) ...[
              const SizedBox(height: 22),
              _StudioQuickActionTile(
                icon: Icons.add_comment_outlined,
                label: 'Start Chat',
                subtitle: 'Open a fresh studio thread',
                color: _studioAccent,
                foreground: Colors.black,
                onTap: _openConversationComposer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openThread(String threadId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrowthChatThreadScreen(
          threadId: threadId,
          scope: widget.scope,
          adminMode: _isAdmin,
        ),
      ),
    );
  }

  Future<void> _openConversationComposer() async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ConversationComposerSheet(
          scope: widget.scope,
          currentUser: user,
          allUsers: _allUsers,
          store: _store,
          adminMode: _isAdmin,
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (result != null && result.isNotEmpty) {
      _openThread(result);
    }
  }

  Future<void> _showPermissionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GrowthMessagingPermissionSheet(
          store: _store,
          users: _allUsers,
        );
      },
    );
  }

  Future<void> _openBroadcastThread() async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    final thread = await _store.ensureBroadcastThread(
      scope: widget.scope,
      adminId: user.id,
      adminName: user.name,
    );

    if (!mounted) {
      return;
    }

    _openThread(thread.id);
  }
}

class GrowthChatThreadScreen extends StatefulWidget {
  const GrowthChatThreadScreen({
    super.key,
    required this.threadId,
    required this.scope,
    this.adminMode = false,
  });

  final String threadId;
  final GrowthChatScope scope;
  final bool adminMode;

  @override
  State<GrowthChatThreadScreen> createState() => _GrowthChatThreadScreenState();
}

class _GrowthChatThreadScreenState extends State<GrowthChatThreadScreen> {
  final GrowthMessagingStore _store = GrowthMessagingStore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  UserAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await UserAccountService.instance.initialize();
    final user = UserAccountService.instance.currentUser;
    await _store.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = user;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final thread = _store.findThread(widget.threadId);

    if (thread == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050C1C),
        appBar: AppBar(
          backgroundColor: Colors.black.withAlpha((0.6 * 255).round()),
          title: const Text('Conversation'),
        ),
        body: const Center(
          child: Text(
            'Conversation not found.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050C1C),
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha((0.6 * 255).round()),
        title: Text(thread.title),
        actions: [
          if (_canRenameThread(thread))
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Rename group',
              onPressed: () => _promptRenameThread(thread),
            ),
          if (_canRenameThread(thread))
            IconButton(
              icon: Icon(
                thread.isLocked ? Icons.lock_open : Icons.lock_outline,
              ),
              tooltip: thread.isLocked ? 'Open group' : 'Close group',
              onPressed: () => _toggleThreadLockState(thread),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _store,
              builder: (context, _) {
                final updatedThread = _store.findThread(widget.threadId);
                final messages =
                    (updatedThread?.messages ?? <GrowthChatMessage>[])
                        .where((message) => message.deletedAt == null)
                        .toList(growable: false);
                final isBroadcast = updatedThread?.isBroadcast ?? false;
                final isLocked = updatedThread?.isLocked ?? false;

                final viewer = _currentUser;
                if (updatedThread != null && viewer != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _store.markThreadRead(
                      userId: viewer.id,
                      threadId: updatedThread.id,
                    );
                  });
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBroadcast)
                            const Icon(
                              Icons.campaign_outlined,
                              color: Colors.tealAccent,
                              size: 56,
                            )
                          else
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white54,
                              size: 48,
                            ),
                          const SizedBox(height: 16),
                          Text(
                            isBroadcast
                                ? 'Kick off the studio broadcast with your first announcement.'
                                : 'No messages yet. Break the silence!',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          if (isLocked) ...[
                            const SizedBox(height: 16),
                            const _ThreadLockedBanner(),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                final children = <Widget>[];
                if (isBroadcast) {
                  children.add(const _BroadcastNotice());
                }
                if (isLocked) {
                  children.add(const _ThreadLockedBanner());
                }

                for (final message in messages) {
                  final isMe = user != null && message.senderId == user.id;
                  Widget bubble = _MessageBubble(message: message, isMe: isMe);
                  final threadSnapshot = updatedThread;
                  if (threadSnapshot != null &&
                      _canDeleteMessage(threadSnapshot, message)) {
                    bubble = GestureDetector(
                      onLongPress: () =>
                          _confirmDeleteMessage(threadSnapshot, message),
                      child: bubble,
                    );
                  }
                  children.add(bubble);
                }

                final callHistory = _buildCallHistory(updatedThread);
                children.add(callHistory);

                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: children,
                );
              },
            ),
          ),
          _buildComposer(thread, user),
        ],
      ),
    );
  }

  Widget _buildComposer(GrowthChatThread thread, UserAccount? user) {
    final effectiveThread = _store.findThread(thread.id) ?? thread;
    final isLocked = effectiveThread.isLocked;
    final userAccount = user;
    final canSend = userAccount != null && !isLocked;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final Color composerBackground = const Color(0xFF050D1E);
    final Color inputFill = canSend
        ? Colors.white.withAlpha((0.12 * 255).round())
        : Colors.white.withAlpha((0.05 * 255).round());

    Widget actionButton({
      required IconData icon,
      required VoidCallback? onTap,
      Color? background,
      Color? iconColor,
    }) {
      final bool enabled = onTap != null;
      final Color baseBackground =
          background ?? Colors.black.withAlpha((0.38 * 255).round());
    final double baseAlpha = baseBackground.a;
    final Color effectiveBackground = enabled
      ? baseBackground
      : baseBackground.withValues(alpha: baseAlpha * 0.35);
      final Color effectiveIcon = iconColor ??
          (enabled
              ? Colors.white.withAlpha((0.92 * 255).round())
              : Colors.white.withAlpha((0.45 * 255).round()));

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: effectiveBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withAlpha((0.08 * 255).round()),
            ),
          ),
          child: Icon(icon, color: effectiveIcon, size: 22),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomInset),
      decoration: BoxDecoration(
        color: composerBackground.withAlpha((0.96 * 255).round()),
        border: Border(
          top: BorderSide(
            color: Colors.white.withAlpha((0.08 * 255).round()),
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Colors.orangeAccent.withAlpha((0.82 * 255).round()),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Studio messaging is closed until an admin reopens it.',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withAlpha((0.1 * 255).round()),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, _) {
                final bool hasText = value.text.trim().isNotEmpty;
                final bool enableSend = canSend && hasText;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    actionButton(
                      icon: Icons.image_outlined,
                      onTap: canSend
                          ? () => _startImageSelection(thread, userAccount)
                          : null,
                      background:
                          Colors.black.withAlpha((0.32 * 255).round()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: canSend,
                        minLines: 1,
                        maxLines: 5,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: !canSend
                              ? (userAccount == null
                                  ? 'Sign in to send messages'
                                  : 'The studio is closed for now')
                              : 'Share something with the studio...',
                          hintStyle: TextStyle(
                            color: Colors.white
                                .withAlpha((0.48 * 255).round()),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: enableSend
                          ? () => _sendCurrentMessage(thread, userAccount)
                          : null,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: enableSend
                                ? [
                                    _studioAccent,
                                    _studioAccentSecondary,
                                  ]
                                : [
                                    Colors.white
                                        .withAlpha((0.12 * 255).round()),
                                    Colors.white
                                        .withAlpha((0.05 * 255).round()),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: enableSend
                              ? const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: enableSend
                                  ? Colors.black
                                  : Colors.white.withAlpha((0.6 * 255).round()),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Send',
                              style: TextStyle(
                                color: enableSend
                                    ? Colors.black
                                    : Colors.white.withAlpha((0.7 * 255).round()),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallHistory(GrowthChatThread? thread) {
    if (thread == null || thread.callHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.04 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withAlpha((0.07 * 255).round()),
          ),
        ),
        child: ExpansionTile(
          collapsedIconColor: Colors.tealAccent,
          iconColor: Colors.tealAccent,
          textColor: Colors.white,
          collapsedTextColor: Colors.white70,
          title: const Text(
            'Call Studio History',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          children: thread.callHistory.reversed.map((record) {
            final icon = record.type == GrowthChatCallType.voice
                ? Icons.call
                : Icons.videocam;
            final label = record.type == GrowthChatCallType.voice
                ? 'Voice call'
                : 'Video call';
            final timeLabel = _formatCallTime(record.timestamp);
            return ListTile(
              dense: true,
              leading: Icon(icon, color: Colors.tealAccent),
              title: Text(
                '$label with ${record.initiatorName}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                timeLabel,
                style: TextStyle(
                  color: Colors.white.withAlpha((0.65 * 255).round()),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatCallTime(DateTime timestamp) {
    final date = timestamp;
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.month}/${date.day} • $time';
  }

  void _sendCurrentMessage(GrowthChatThread thread, UserAccount? user) {
    final account = user;
    if (account == null) {
      return;
    }
    unawaited(_handleSend(thread, account));
  }

  void _startImageSelection(GrowthChatThread thread, UserAccount? user) {
    final account = user;
    if (account == null) {
      return;
    }
    unawaited(_handleImageSend(thread, account));
  }

  Future<void> _handleSend(GrowthChatThread thread, UserAccount user) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _messageController.clear();
    await _store.sendTextMessage(
      threadId: thread.id,
      senderId: user.id,
      senderName: user.name,
      content: text,
    );
  }

  Future<void> _handleImageSend(
    GrowthChatThread thread,
    UserAccount user,
  ) async {
    try {
      final pick = await _picker.pickImage(source: ImageSource.gallery);
      if (pick == null) {
        return;
      }

      final file = kIsWeb ? File(pick.path) : File(pick.path);
      await _store.sendImageMessage(
        threadId: thread.id,
        senderId: user.id,
        senderName: user.name,
        content: _messageController.text,
        source: file,
      );
      _messageController.clear();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not attach image: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  bool _canRenameThread(GrowthChatThread thread) {
    if (!thread.isGroup || thread.isBroadcast) {
      return false;
    }
    final user = _currentUser;
    if (user == null) {
      return false;
    }
    final participant = _participantForUser(thread, user.id);
    return participant?.isAdmin ?? false;
  }

  GrowthChatParticipant? _participantForUser(
    GrowthChatThread thread,
    String userId,
  ) {
    for (final participant in thread.participants) {
      if (participant.userId == userId) {
        return participant;
      }
    }
    return null;
  }

  bool _canDeleteMessage(GrowthChatThread thread, GrowthChatMessage message) {
    final user = _currentUser;
    if (user == null) {
      return false;
    }
    if (message.senderId == user.id) {
      return true;
    }
    final participant = _participantForUser(thread, user.id);
    return participant?.isAdmin ?? false;
  }

  Future<void> _promptRenameThread(GrowthChatThread thread) async {
    final controller = TextEditingController(text: thread.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111B34),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Rename group',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Group name',
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.tealAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null) {
      return;
    }
    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed == thread.title) {
      return;
    }

    await _store.renameThread(thread.id, trimmed);
    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Group name updated'),
        backgroundColor: Colors.tealAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeleteMessage(
    GrowthChatThread thread,
    GrowthChatMessage message,
  ) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111B34),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Delete this message?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'The message disappears now and will be purged from storage after two days.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final success = await _store.deleteMessage(
      threadId: thread.id,
      messageId: message.id,
      requestorId: user.id,
    );

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Message deleted'),
          backgroundColor: Colors.tealAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('You cannot delete this message'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleThreadLockState(GrowthChatThread thread) async {
    final shouldLock = !thread.isLocked;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final title = shouldLock ? 'Close studio chat?' : 'Open studio chat?';
        final message = shouldLock
            ? 'No one will be able to send messages until the chat is reopened.'
            : 'Members will be able to resume messaging in this studio.';
        return AlertDialog(
          backgroundColor: const Color(0xFF111B34),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    shouldLock ? Colors.orangeAccent : Colors.tealAccent,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(shouldLock ? 'Close chat' : 'Open chat'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await _store.setThreadLockState(thread.id, shouldLock);
    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(shouldLock ? 'Studio chat closed' : 'Studio chat reopened'),
        backgroundColor: shouldLock ? Colors.orangeAccent : Colors.tealAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _BroadcastNotice extends StatelessWidget {
  const _BroadcastNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withAlpha((0.2 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, color: Colors.black54),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Messages in this thread reach every member of the studio.',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadLockedBanner extends StatelessWidget {
  const _ThreadLockedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withAlpha((0.2 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.black54),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'The studio is currently closed. An admin can reopen the conversation at any time.',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  final GrowthChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textColor = isMe ? Colors.black : Colors.white;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(26),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(22),
          );
    final gradient = isMe
        ? LinearGradient(
            colors: [
              _studioAccent,
              _studioAccentSecondary.withAlpha((0.82 * 255).round()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [
              Color(0xFF1A2C4F),
              Color(0xFF0D162C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final shadow = isMe
        ? const BoxShadow(
            color: Color(0x88000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        : const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          );

    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        bottom: 12,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              message.senderName,
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: radius,
              boxShadow: [shadow],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: align,
              children: [
                if (message.type == GrowthChatMessageType.image &&
                    message.imagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MessageImage(
                      path: message.imagePath!,
                      messageId: message.id,
                    ),
                  ),
                if (message.content.isNotEmpty)
                  Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      color: isMe
                          ? Colors.black.withAlpha((0.6 * 255).round())
                          : Colors.white.withAlpha((0.6 * 255).round()),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final hours = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minutes = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hours:$minutes $period';
  }
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.path, required this.messageId});

  final String path;
  final String messageId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPreview(context),
      child: Hero(
        tag: 'growth-chat-image-$messageId',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildImageWidget(fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildImageWidget({BoxFit fit = BoxFit.contain}) {
    if (kIsWeb) {
      return Image.network(path, fit: fit);
    }
    return Image.file(File(path), fit: fit);
  }

  void _openPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.85 * 255).round()),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Hero(
            tag: 'growth-chat-image-$messageId',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: _buildImageWidget(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConversationComposerSheet extends StatefulWidget {
  const _ConversationComposerSheet({
    required this.scope,
    required this.currentUser,
    required this.allUsers,
    required this.store,
    required this.adminMode,
  });

  final GrowthChatScope scope;
  final UserAccount currentUser;
  final List<UserAccount> allUsers;
  final GrowthMessagingStore store;
  final bool adminMode;

  @override
  State<_ConversationComposerSheet> createState() =>
      _ConversationComposerSheetState();
}

class _ConversationComposerSheetState
    extends State<_ConversationComposerSheet> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _manualIdentifierController =
      TextEditingController();
  final Map<String, GrowthChatParticipant> _selectedParticipants =
      <String, GrowthChatParticipant>{};
  bool _isGroup = false;
  bool _saving = false;
  bool _manualLookupBusy = false;
  String? _manualLookupMessage;
  bool _manualLookupSuccess = false;
  GrowthDirectoryEntry? _lookupPreview;
  bool _openingBroadcast = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _manualIdentifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableUsers = widget.allUsers
        .where((user) => user.id != widget.currentUser.id)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final selectedValues = _selectedParticipants.values.toList(growable: false);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B142A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withAlpha((0.08 * 255).round()),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.chat_outlined, color: Colors.tealAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isGroup
                        ? 'Create a studio group chat'
                        : 'Start a direct conversation',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  thumbColor: WidgetStateProperty.all(Colors.tealAccent),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => Colors.tealAccent.withAlpha(
                      states.contains(WidgetState.selected)
                          ? (0.47 * 255).round()
                          : (0.23 * 255).round(),
                    ),
                  ),
                  value: _isGroup,
                  onChanged: (value) {
                    setState(() {
                      _isGroup = value;
                      if (!value && _selectedParticipants.length > 1) {
                        final firstEntry = _selectedParticipants.entries.first;
                        _selectedParticipants
                          ..clear()
                          ..putIfAbsent(firstEntry.key, () => firstEntry.value);
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.adminMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  onPressed:
                      _openingBroadcast ? null : _handleBroadcastShortcut,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.tealAccent.withAlpha((0.4 * 255).round()),
                    ),
                    foregroundColor: Colors.tealAccent,
                  ),
                  icon: _openingBroadcast
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: const Text('Open studio broadcast'),
                ),
              ),
            if (_isGroup)
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'Group name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.06 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                    ),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            SizedBox(height: _isGroup ? 18 : 0),
            Text(
              _isGroup ? 'Select members' : 'Select recipient',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (selectedValues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedValues.map((participant) {
                    return InputChip(
                      label: Text(
                        participant.displayName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor:
                          Colors.tealAccent.withAlpha((0.2 * 255).round()),
                      deleteIconColor: Colors.white,
                      onDeleted: () {
                        setState(() {
                          _selectedParticipants.remove(participant.userId);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableUsers.length,
                itemBuilder: (context, index) {
                  final user = availableUsers[index];
                  final selected = _selectedParticipants.containsKey(user.id);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _addParticipant(_participantForUser(user));
                        } else {
                          _selectedParticipants.remove(user.id);
                        }
                      });
                    },
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.tealAccent;
                      }
                      return Colors.white.withAlpha((0.3 * 255).round());
                    }),
                    checkColor: Colors.black,
                    title: Text(
                      user.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      user.email,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            if (widget.adminMode) ...[
              const SizedBox(height: 20),
              Divider(color: Colors.white.withAlpha((0.12 * 255).round())),
              const SizedBox(height: 16),
              const Text(
                'Add by ID or phone',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualIdentifierController,
                decoration: InputDecoration(
                  labelText: 'Member ID or phone number',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.06 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                    ),
                  ),
                  helperText: 'Paste a GR/GI ID or enter the phone number.',
                  helperStyle: TextStyle(
                    color: Colors.white.withAlpha((0.4 * 255).round()),
                    fontSize: 11,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _manualLookupBusy ? null : _handleManualLookup,
                  icon: _manualLookupBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Find member'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              if (_lookupPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _LookupPreviewCard(
                    entry: _lookupPreview!,
                    onAdd: _confirmPreviewAdd,
                    isAlreadySelected: _selectedParticipants
                        .containsKey(_lookupPreview!.userId),
                  ),
                ),
              if (_manualLookupMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _manualLookupMessage!,
                    style: TextStyle(
                      color: _manualLookupSuccess
                          ? Colors.tealAccent
                          : Colors.orangeAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withAlpha((0.4 * 255).round()),
                      ),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _handleCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isGroup ? Icons.groups : Icons.person),
                    label: Text(_isGroup ? 'Create group' : 'Start chat'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    if (_saving) {
      return;
    }
    if (!_isGroup && _selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one participant'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isGroup && _selectedParticipants.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Direct chats can only include one recipient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      if (_isGroup) {
        await _createGroup();
      } else {
        await _createDirectChat();
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create conversation: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _createDirectChat() async {
    final target = _selectedParticipants.values.first;

    final requester = GrowthChatParticipant(
      userId: widget.currentUser.id,
      displayName: widget.currentUser.name,
      isAdmin: widget.adminMode,
      canCreateGroups: widget.store.canUserCreateGroup(widget.currentUser.id),
    );
    final other = target.copyWith(
      canCreateGroups: widget.store.canUserCreateGroup(target.userId),
      isAdmin: false,
    );

    await widget.store.ensureDirectThread(
      scope: widget.scope,
      requester: requester,
      other: other,
    );
  }

  Future<void> _createGroup() async {
    final participants = <GrowthChatParticipant>[];
    participants.add(
      GrowthChatParticipant(
        userId: widget.currentUser.id,
        displayName: widget.currentUser.name,
        isAdmin: true,
        canCreateGroups: true,
      ),
    );

    for (final participant in _selectedParticipants.values) {
      if (participant.userId == widget.currentUser.id) {
        continue;
      }
      participants.add(
        participant.copyWith(
          canCreateGroups: widget.store.canUserCreateGroup(participant.userId),
          isAdmin: false,
        ),
      );
    }

    await widget.store.createGroupThread(
      scope: widget.scope,
      title: _groupNameController.text,
      createdBy: widget.currentUser.id,
      participants: participants,
    );
  }

  GrowthChatParticipant _participantForUser(UserAccount user) {
    return GrowthChatParticipant(
      userId: user.id,
      displayName: user.name,
      isAdmin: false,
      canCreateGroups: widget.store.canUserCreateGroup(user.id),
    );
  }

  void _addParticipant(GrowthChatParticipant participant) {
    if (participant.userId == widget.currentUser.id) {
      return;
    }
    if (!_isGroup) {
      _selectedParticipants
        ..clear()
        ..putIfAbsent(participant.userId, () => participant);
    } else {
      _selectedParticipants[participant.userId] = participant;
    }
  }

  Future<void> _handleManualLookup() async {
    if (_manualLookupBusy) {
      return;
    }

    final query = _manualIdentifierController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _manualLookupMessage = 'Enter a member ID or phone number.';
        _manualLookupSuccess = false;
        _lookupPreview = null;
      });
      return;
    }

    setState(() {
      _manualLookupBusy = true;
      _manualLookupMessage = null;
    });

    try {
      var entry = await GrowthUserDirectory.instance.findByIdOrPhone(
        userId: query,
        phone: query,
      );

      entry ??= _matchUserAccountFallback(query);

      if (entry == null) {
        setState(() {
          _lookupPreview = null;
          _manualLookupMessage = 'No matching member was found.';
          _manualLookupSuccess = false;
        });
        return;
      }

      final resolvedEntry = entry;

      if (resolvedEntry.scope != widget.scope) {
        setState(() {
          _lookupPreview = null;
      final scopeLabel = resolvedEntry.scope.shortLabel;
      _manualLookupMessage =
        'That member belongs to the $scopeLabel studio. Switch studios to include them.';
          _manualLookupSuccess = false;
        });
        return;
      }

      if (resolvedEntry.userId == widget.currentUser.id) {
        setState(() {
          _lookupPreview = null;
          _manualLookupMessage = 'You are already part of this studio chat.';
          _manualLookupSuccess = false;
        });
        return;
      }

      if (_selectedParticipants.containsKey(resolvedEntry.userId)) {
        setState(() {
          _lookupPreview = null;
          _manualLookupMessage =
              '${resolvedEntry.displayName} is already selected.';
          _manualLookupSuccess = true;
        });
        return;
      }

      setState(() {
        _lookupPreview = resolvedEntry;
        _manualLookupSuccess = true;
        _manualLookupMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _manualLookupBusy = false;
        });
      }
    }
  }

  void _confirmPreviewAdd() {
    final entry = _lookupPreview;
    if (entry == null) {
      return;
    }

    if (_selectedParticipants.containsKey(entry.userId)) {
      setState(() {
        _manualLookupMessage = '${entry.displayName} is already selected.';
        _manualLookupSuccess = true;
      });
      return;
    }

    final participant = GrowthChatParticipant(
      userId: entry.userId,
      displayName: entry.displayName,
      isAdmin: false,
      canCreateGroups: widget.store.canUserCreateGroup(entry.userId),
    );

    setState(() {
      _addParticipant(participant);
      _lookupPreview = null;
      _manualIdentifierController.clear();
      _manualLookupMessage = 'Added ${participant.displayName}.';
      _manualLookupSuccess = true;
    });
  }

  GrowthDirectoryEntry? _matchUserAccountFallback(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final user in widget.allUsers) {
      final idMatch = user.id.toLowerCase() == normalized;
      final emailMatch = user.email.toLowerCase() == normalized;
      if (!idMatch && !emailMatch) {
        continue;
      }
      final display = user.name.isNotEmpty ? user.name : 'Member';
      return GrowthDirectoryEntry(
        userId: user.id,
        displayName: display,
        rawKey: display,
        scope: widget.scope,
        phone: '',
      );
    }

    return null;
  }

  Future<void> _handleBroadcastShortcut() async {
    if (_openingBroadcast) {
      return;
    }

    setState(() {
      _openingBroadcast = true;
    });

    try {
      final thread = await widget.store.ensureBroadcastThread(
        scope: widget.scope,
        adminId: widget.currentUser.id,
        adminName: widget.currentUser.name,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(thread.id);
    } finally {
      if (mounted) {
        setState(() {
          _openingBroadcast = false;
        });
      }
    }
  }
}

class _LookupPreviewCard extends StatelessWidget {
  const _LookupPreviewCard({
    required this.entry,
    required this.onAdd,
    required this.isAlreadySelected,
  });

  final GrowthDirectoryEntry entry;
  final VoidCallback onAdd;
  final bool isAlreadySelected;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (entry.profileBase64 != null && entry.profileBase64!.isNotEmpty) {
      try {
        bytes = base64Decode(entry.profileBase64!);
      } catch (_) {
        bytes = null;
      }
    }

  final scopeLabel = '${entry.scope.shortLabel} studio member';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.tealAccent.withAlpha((0.25 * 255).round())),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    Colors.tealAccent.withAlpha((0.25 * 255).round()),
                backgroundImage: bytes != null ? MemoryImage(bytes) : null,
                child: bytes == null
                    ? Text(
                        entry.displayName.isNotEmpty
                            ? entry.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.userId,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    if (entry.phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          entry.phone,
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.55 * 255).round()),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              scopeLabel,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isAlreadySelected ? null : onAdd,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(isAlreadySelected ? 'Already added' : 'Add to chat'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    Colors.white.withAlpha((0.2 * 255).round()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GrowthMessagingPermissionSheet extends StatefulWidget {
  const GrowthMessagingPermissionSheet({
    super.key,
    required this.store,
    required this.users,
  });

  final GrowthMessagingStore store;
  final List<UserAccount> users;

  @override
  State<GrowthMessagingPermissionSheet> createState() =>
      GrowthMessagingPermissionSheetState();
}

class GrowthMessagingPermissionSheetState
    extends State<GrowthMessagingPermissionSheet> {
  final Map<String, bool> _pending = <String, bool>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final map = widget.store.groupCreatorMap;
    for (final user in widget.users) {
      _pending[user.id] = map[user.id] ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.users.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B142A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withAlpha((0.08 * 255).round()),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Group creator permissions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final user = entries[index];
                  final allowed = _pending[user.id] ?? false;
                  return SwitchListTile(
                    value: allowed,
                    onChanged: (value) {
                      setState(() {
                        _pending[user.id] = value;
                      });
                    },
                    thumbColor: WidgetStateProperty.all(Colors.tealAccent),
                    trackColor: WidgetStateProperty.resolveWith(
                      (states) => Colors.tealAccent.withAlpha(
                        states.contains(WidgetState.selected)
                            ? (0.47 * 255).round()
                            : (0.23 * 255).round(),
                      ),
                    ),
                    title: Text(
                      user.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      user.email,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withAlpha((0.4 * 255).round()),
                      ),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _apply,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apply() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      for (final entry in _pending.entries) {
        await widget.store.setUserGroupPermission(entry.key, entry.value);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}
