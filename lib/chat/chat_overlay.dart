import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'chat_input_bar.dart';

class ChatOverlay extends StatelessWidget {
  const ChatOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.radiusSheet),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(Icons.shield, color: theme.colorScheme.primary),
                ),
                title: const Text('THERMOLOX Assistent'),
                subtitle: const Text('Frag mich alles zu deinem Projekt'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: const [
                    Text(
                      'Hier kommt später dein echter Chatverlauf hin – '
                      'inkl. Anbindung an deinen Cloudflare-Worker / GPT.',
                    ),
                  ],
                ),
              ),
              const ChatInputBar(),
            ],
          ),
        );
      },
    );
  }
}
