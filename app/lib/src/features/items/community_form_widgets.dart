import 'package:flutter/material.dart';

import '../../theme/ruhamaa_theme.dart';

/// One tile of the eight-tile category grid used by the donation and request
/// forms. [key] is the V2 catalog key the server stores.
class CommunityCategory {
  const CommunityCategory({required this.key, required this.label, required this.icon});

  final String key;
  final String label;
  final IconData icon;
}

/// The categories of the community forms, in the order of the mockups.
const communityCategories = <CommunityCategory>[
  CommunityCategory(key: 'clothes', label: 'ملابس', icon: Icons.checkroom_outlined),
  CommunityCategory(key: 'children', label: 'مستلزمات أطفال', icon: Icons.child_care_outlined),
  CommunityCategory(key: 'education', label: 'تعليم', icon: Icons.menu_book_outlined),
  CommunityCategory(key: 'home_furniture', label: 'أثاث', icon: Icons.weekend_outlined),
  CommunityCategory(key: 'electronics', label: 'أجهزة', icon: Icons.desktop_windows_outlined),
  CommunityCategory(key: 'tools_trades', label: 'أدوات', icon: Icons.build_outlined),
  CommunityCategory(key: 'events', label: 'مناسبات', icon: Icons.star_outline_rounded),
  CommunityCategory(key: 'other', label: 'أخرى', icon: Icons.more_horiz_rounded),
];

/// Green for giving, gold for asking.
enum CommunityTone {
  give,
  need;

  Color get action => this == give ? RuhamaaColors.primary : RuhamaaColors.goldDark;
  Color get link => this == give ? RuhamaaColors.primary : RuhamaaColors.goldDeep;
  Color get tileSelected => this == give ? RuhamaaColors.mintStrong : RuhamaaColors.goldSelected;
  Color get iconBackground => this == give ? RuhamaaColors.mint : RuhamaaColors.goldTint;
  Color get selectedText => this == give ? RuhamaaColors.primaryDark : const Color(0xFF5C3F0C);

  /// Background of the step numbers after the first one.
  Color get stepSoft => this == give ? RuhamaaColors.mintStrong : RuhamaaColors.goldSelected;
}

/// App bar of the community forms: a round back button and the screen title
/// aligned to the start, as in the mockups.
PreferredSizeWidget communityAppBar({
  required String title,
  required VoidCallback onBack,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    centerTitle: false,
    toolbarHeight: 68,
    titleSpacing: 16,
    backgroundColor: RuhamaaColors.background,
    title: Row(
      children: [
        _RoundBackButton(onPressed: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: RuhamaaColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'رجوع',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: RuhamaaColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox.square(
            dimension: 44,
            child: IconTheme(
              data: IconThemeData(color: RuhamaaColors.text, size: 22),
              child: Center(child: BackButtonIcon()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section label above a field (17, extra bold).
class CommunityFieldLabel extends StatelessWidget {
  const CommunityFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: RuhamaaColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Four-column grid of [communityCategories].
class CommunityCategoryGrid extends StatelessWidget {
  const CommunityCategoryGrid({
    super.key,
    required this.selected,
    required this.onChanged,
    this.tone = CommunityTone.give,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final CommunityTone tone;

  static const _columns = 4;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < communityCategories.length; start += _columns) {
      final cells = <Widget>[];
      for (var index = start; index < start + _columns; index++) {
        if (index > start) cells.add(const SizedBox(width: 8));
        cells.add(
          Expanded(
            child: index < communityCategories.length
                ? _CategoryTile(
                    category: communityCategories[index],
                    selected: communityCategories[index].key == selected,
                    tone: tone,
                    onTap: () => onChanged(communityCategories[index].key),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
    }
    return Column(children: rows);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.tone,
    required this.onTap,
  });

  final CommunityCategory category;
  final bool selected;
  final CommunityTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: selected
          ? BorderSide(color: tone.action, width: 2)
          : const BorderSide(color: RuhamaaColors.border),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? tone.tileSelected : Colors.white,
        shape: shape,
        child: InkWell(
          key: ValueKey('category-${category.key}'),
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: 104,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 9),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? tone.action : tone.iconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category.icon,
                      size: 24,
                      color: selected ? Colors.white : tone.action,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      category.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? tone.selectedText : RuhamaaColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text field decoration of the forms: white, rounded, 14 px padding.
InputDecoration communityInputDecoration({
  required String hint,
  required CommunityTone tone,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF7B8B8E), fontSize: 16),
    counterText: '',
    contentPadding: const EdgeInsets.all(14),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: tone.action, width: 1.5),
    ),
  );
}

/// «يُستلم من عنوانك: …» with a «تغيير» link to the address screen.
class CommunityAddressLine extends StatelessWidget {
  const CommunityAddressLine({
    super.key,
    required this.prefix,
    required this.area,
    required this.loaded,
    required this.onChange,
    this.tone = CommunityTone.give,
  });

  /// e.g. «يُستلم من عنوانك».
  final String prefix;

  /// The default address area, when known.
  final String? area;

  /// False while the address is still loading or could not be read.
  final bool loaded;
  final VoidCallback onChange;
  final CommunityTone tone;

  @override
  Widget build(BuildContext context) {
    final place = area?.trim() ?? '';
    final missing = loaded && place.isEmpty;
    final String text;
    if (place.isNotEmpty) {
      text = '$prefix: $place';
    } else if (missing) {
      text = 'أضف عنوانك ليصل إليك الموصل';
    } else {
      text = '$prefix المسجّل';
    }
    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 20, color: tone.link),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: RuhamaaColors.bodyMuted, fontSize: 14, height: 1.4),
          ),
        ),
        TextButton(
          onPressed: onChange,
          style: TextButton.styleFrom(foregroundColor: tone.link),
          child: Text(
            missing ? 'إضافة' : 'تغيير',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Full-width pill button (58 high) used for the main action of a screen.
class CommunityPillButton extends StatelessWidget {
  const CommunityPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = RuhamaaColors.primary,
    this.showArrow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: .55),
          disabledForegroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, fontFamily: 'Tajawal'),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            if (showArrow) ...[
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}

/// Soft panel with an icon and a sentence (privacy banner, info notes).
class CommunityNote extends StatelessWidget {
  const CommunityNote({
    super.key,
    required this.icon,
    required this.text,
    this.background = RuhamaaColors.sand,
    this.iconColor = RuhamaaColors.goldDeep,
    this.textColor = RuhamaaColors.noteText,
    this.radius = 18,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color iconColor;
  final Color textColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: textColor, fontSize: 14, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

/// Top of the "sent" view: brand mark in a soft circle, heading, message and
/// the reference code chip.
class CommunitySentSummary extends StatelessWidget {
  const CommunitySentSummary({
    super.key,
    required this.heading,
    required this.message,
    required this.codeLabel,
    required this.code,
    this.tone = CommunityTone.give,
  });

  final String heading;
  final String message;
  final String codeLabel;
  final String code;
  final CommunityTone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox.square(
          dimension: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(color: tone.iconBackground, shape: BoxShape.circle),
              ),
              const RuhamaaBrandMark(size: 160),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          heading,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RuhamaaColors.text,
            fontSize: 28,
            height: 38 / 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: RuhamaaColors.bodyMuted, fontSize: 17, height: 27 / 17),
        ),
        if (code.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RuhamaaColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$codeLabel: ',
                  style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 14),
                ),
                Flexible(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      code,
                      style: const TextStyle(
                        color: RuhamaaColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// «ماذا يحدث الآن؟» card with numbered steps.
class CommunityNextSteps extends StatelessWidget {
  const CommunityNextSteps({
    super.key,
    required this.steps,
    this.tone = CommunityTone.give,
  });

  final List<String> steps;
  final CommunityTone tone;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Text(
        'ماذا يحدث الآن؟',
        style: TextStyle(color: RuhamaaColors.text, fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ];
    for (var index = 0; index < steps.length; index++) {
      final first = index == 0;
      children
        ..add(const SizedBox(height: 14))
        ..add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: first ? tone.action : tone.stepSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: first ? Colors.white : tone.selectedText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    steps[index],
                    style: const TextStyle(color: RuhamaaColors.text, fontSize: 15, height: 22 / 15),
                  ),
                ),
              ),
            ],
          ),
        );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RuhamaaColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
