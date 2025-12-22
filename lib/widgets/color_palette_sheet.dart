import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/thermolox_palette.dart';
import '../theme/app_theme.dart';
import '../utils/color_utils.dart';
import '../utils/thermolox_overlay.dart';

Future<String?> showColorPaletteSheet(
  BuildContext context, {
  String? initialHex,
}) {
  return ThermoloxOverlay.showSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ColorPaletteSheet(initialHex: initialHex),
  );
}

class _ColorPaletteSheet extends StatefulWidget {
  final String? initialHex;

  const _ColorPaletteSheet({this.initialHex});

  @override
  State<_ColorPaletteSheet> createState() => _ColorPaletteSheetState();
}

class _ColorPaletteSheetState extends State<_ColorPaletteSheet> {
  late final TextEditingController _controller;
  String? _nearestHex;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialHex ?? '');
    _nearestHex = widget.initialHex != null
        ? nearestPaletteHex(widget.initialHex!, thermoloxPalette)
        : null;
    _controller.addListener(_updateNearest);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateNearest);
    _controller.dispose();
    super.dispose();
  }

  void _updateNearest() {
    final next = nearestPaletteHex(_controller.text, thermoloxPalette);
    if (next == _nearestHex || !mounted) return;
    setState(() => _nearestHex = next);
  }

  Color _onColorForBackground(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.7;

    final previewColor =
        _nearestHex != null ? colorFromHex(_nearestHex!) : null;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.screenPadding,
          tokens.gapMd,
          tokens.screenPadding,
          tokens.gapMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Farbe auswählen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: tokens.gapMd),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nach HEX-Code suchen',
                hintText: '#AABBCC',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp('[0-9a-fA-F#]'),
                ),
              ],
            ),
            SizedBox(height: tokens.gapMd),
            if (previewColor != null)
              InkWell(
                onTap: () => Navigator.of(context).pop(_nearestHex),
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                child: Container(
                  height: 86,
                  decoration: BoxDecoration(
                    color: previewColor,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.08),
                    ),
                  ),
                ),
              ),
            SizedBox(height: tokens.gapMd),
            Expanded(
              child: GridView.builder(
                itemCount: thermoloxPalette.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: tokens.gapSm,
                  crossAxisSpacing: tokens.gapSm,
                ),
                itemBuilder: (context, index) {
                  final color = thermoloxPalette[index];
                  final hex = hexFromColor(color);
                  final isSelected = hex == _nearestHex;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(hex),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.08),
                        ),
                      ),
                      child: isSelected
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final size =
                                    constraints.biggest.shortestSide * 0.75;
                                return Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: _onColorForBackground(color),
                                    size: size,
                                  ),
                                );
                              },
                            )
                          : null,
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
