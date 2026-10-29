import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/blab_avatar.dart';

class MentionCandidate {
  const MentionCandidate(this.userId, this.displayName);
  final String userId, displayName;
  String get mentionLabel => displayName.trim().split(RegExp(r'\s+')).first;
}

class MentionPicker extends StatelessWidget {
  const MentionPicker({
    super.key,
    required this.candidates,
    required this.query,
    required this.onSelected,
    required this.onDismiss,
  });
  final List<MentionCandidate> candidates;
  final String query;
  final ValueChanged<MentionCandidate> onSelected;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) {
    final matches = candidates
        .where((c) => c.displayName.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border.all(color: BlabColors.chatDivider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.noMentionMatches),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: matches.length,
                itemBuilder: (context, i) {
                  final candidate = matches[i];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: BlabAvatar(
                        name: candidate.displayName,
                        size: 32,
                        fontSize: 12,
                        shadows: null,
                      ),
                      title: Text(
                        candidate.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      onTap: () => onSelected(candidate),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
