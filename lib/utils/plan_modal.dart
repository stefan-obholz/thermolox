import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/plan_ui_strings.dart';
import '../controllers/plan_controller.dart';
import '../models/plan_models.dart';
import '../pages/auth_page.dart';
import '../theme/app_theme.dart';
import '../widgets/plan_card_view.dart';
import 'thermolox_overlay.dart';

Future<String?> showPlanModal({
  required BuildContext context,
  required List<PlanCardData> plans,
  required String selectedPlanId,
  String? initialPlanId,
  bool showActionButton = true,
  bool allowDowngrade = false,
}) {
  final initialId = initialPlanId ?? selectedPlanId;
  final initialIndex = math.max(
    0,
    plans.indexWhere((plan) => plan.id == initialId),
  );
  final controller = PageController(initialPage: initialIndex);

  var currentIndex = initialIndex;
  return ThermoloxOverlay.showGlassDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'tarife',
    barrierColor: Colors.black.withAlpha(115),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final tokens = dialogContext.thermoloxTokens;
          final media = MediaQuery.of(dialogContext);
          final screenHeight = media.size.height;
          final screenWidth = media.size.width;
          final outerPad =
              math.max(media.padding.top, media.padding.bottom) + 16;
          final availableHeight = screenHeight - (outerPad * 2);
          final maxWidth = math
              .min(
                screenWidth - (tokens.screenPaddingSm * 2),
                420.0,
              )
              .toDouble();

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: outerPad),
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: maxWidth,
                    height: availableHeight,
                    child: PageView.builder(
                      controller: controller,
                      itemCount: plans.length,
                      onPageChanged: (index) =>
                          setState(() => currentIndex = index),
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        final isSelected = plan.id == selectedPlanId;
                        final isDowngrade =
                            selectedPlanId == 'pro' && plan.id == 'basic';
                        final actionLabel = isSelected
                            ? PlanUiStrings.actionActive
                            : isDowngrade
                                ? PlanUiStrings.actionDowngrade
                                : PlanUiStrings.actionUpgrade;
                        final canTap = showActionButton &&
                            !isSelected &&
                            (!isDowngrade || allowDowngrade);
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.gapSm,
                            vertical: tokens.gapSm,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: TapRegion(
                                      onTapOutside: (_) {
                                        if (index == currentIndex) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                      },
                                      child: PlanCardView(
                                        data: plan,
                                        actionLabel: actionLabel,
                                        canTap: canTap,
                                        isSelected: isSelected,
                                        showActionButton: showActionButton,
                                        onAction: canTap
                                            ? () async {
                                                final planController =
                                                    dialogContext
                                                        .read<PlanController>();
                                                if (plan.id == 'pro' &&
                                                    !planController
                                                        .isLoggedIn) {
                                                  final navigator =
                                                      Navigator.of(
                                                    dialogContext,
                                                    rootNavigator: true,
                                                  );
                                                  await navigator.push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const AuthPage(
                                                        initialTabIndex: 1,
                                                      ),
                                                    ),
                                                  );
                                                  await planController.load(
                                                    force: true,
                                                  );
                                                  if (!planController
                                                      .isLoggedIn) {
                                                    return;
                                                  }
                                                }
                                                if (dialogContext.mounted) {
                                                  Navigator.of(dialogContext)
                                                      .pop(plan.id);
                                                }
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
