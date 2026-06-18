import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SourceLinkWidget extends StatelessWidget {
  final String sourceTitle;
  final String sourceUrl;
  final EdgeInsets? padding;
  final TextStyle? style;

  const SourceLinkWidget({
    super.key,
    required this.sourceTitle,
    required this.sourceUrl,
    this.padding,
    this.style,
  });

  Future<void> _openUrl() async {
    final uri = Uri.parse(sourceUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: _openUrl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 14, color: Colors.blue.shade600),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '出典：$sourceTitle',
                style: (style ?? const TextStyle()).copyWith(
                  color: Colors.blue.shade600,
                  decoration: TextDecoration.underline,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
