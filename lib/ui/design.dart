import 'package:flutter/material.dart';

const violet = Color(0xFFBBA4FF);
const muted = Color(0xFF9691AB);
const mint = Color(0xFF8CE0C1);
Color panel(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF211D30)
    : Colors.white;
Color line(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF342D46)
    : const Color(0xFFE5DDF2);
Color ink(BuildContext c) => Theme.of(c).colorScheme.onSurface;
TextStyle heading(double size) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: -.7,
  height: 1.2,
);

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? panel(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: line(context)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = violet});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? color
            : Color.alphaBlend(Colors.black.withValues(alpha: .35), color),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 27, bottom: 14),
    child: Row(
      children: [
        Expanded(child: Text(title, style: heading(20))),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      backgroundColor: violet,
      foregroundColor: const Color(0xFF241644),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 19),
      ],
    ),
  );
}

class CodeView extends StatelessWidget {
  const CodeView({
    super.key,
    required this.lines,
    this.selected,
    this.onSelect,
    this.large = false,
    this.correct = false,
  });
  final List<String> lines;
  final int? selected;
  final ValueChanged<int>? onSelect;
  final bool large, correct;
  List<TextSpan> highlight(String source) {
    final pattern = RegExp(
      r'''("[^"\n]*"|'[^'\n]*'|\b(?:void|final|const|for|in|if|return|def|class|public|static|int|double|boolean|String|Future|async|await|function|None|null|new)\b|\b\d+\b)''',
    );
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(source)) {
      if (m.start > last) {
        spans.add(TextSpan(text: source.substring(last, m.start)));
      }
      final token = m.group(0)!;
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: token.startsWith('"') || token.startsWith("'")
                ? mint
                : int.tryParse(token) != null
                ? const Color(0xFFFFC58E)
                : violet,
          ),
        ),
      );
      last = m.end;
    }
    spans.add(TextSpan(text: source.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF15121F),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF393047)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF30283E))),
          ),
          child: Row(
            children: [
              for (final c in [
                const Color(0xFFED8E9E),
                const Color(0xFFEAC284),
                mint,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CircleAvatar(radius: 4, backgroundColor: c),
                ),
              const SizedBox(width: 10),
              const Text(
                'code / playground',
                style: TextStyle(
                  fontSize: 11,
                  color: muted,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              const Icon(Icons.code_rounded, color: muted, size: 17),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Semantics(
                      button: onSelect != null,
                      selected: selected == i + 1,
                      label: 'Строка ${i + 1}: ${lines[i]}',
                      child: InkWell(
                        key: ValueKey('line-${i + 1}'),
                        onTap: onSelect == null ? null : () => onSelect!(i + 1),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: 44,
                            minWidth: 310,
                          ),
                          padding: const EdgeInsets.only(left: 14, right: 24),
                          decoration: BoxDecoration(
                            color: selected == i + 1
                                ? (correct ? mint : violet).withValues(
                                    alpha: .17,
                                  )
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: selected == i + 1
                                    ? (correct ? mint : violet)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Text.rich(
                                TextSpan(children: highlight(lines[i])),
                                style: TextStyle(
                                  color: const Color(0xFFE2DDEF),
                                  fontSize: large ? 16 : 13,
                                  height: 1.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
