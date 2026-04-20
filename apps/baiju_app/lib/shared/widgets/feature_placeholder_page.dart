import 'package:flutter/material.dart';

class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    required this.title,
    required this.subtitle,
    required this.highlights,
    required this.sections,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<String> highlights;
  final List<FeatureSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text(title, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: highlights
                .map((item) => Chip(label: Text(item)))
                .toList(),
          ),
          const SizedBox(height: 20),
          for (final section in sections) ...<Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(section.icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            section.title,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(section.description),
                    const SizedBox(height: 14),
                    for (final item in section.items) ...<Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(Icons.circle, size: 8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class FeatureSection {
  const FeatureSection({
    required this.title,
    required this.description,
    required this.items,
    required this.icon,
  });

  final String title;
  final String description;
  final List<String> items;
  final IconData icon;
}
