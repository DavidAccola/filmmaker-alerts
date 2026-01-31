import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/contributor_detail.dart';
import 'external_navigation_utils.dart';

class StreamingOptionsWidget extends StatefulWidget {
  final List<StreamingOption> streamingOptions;
  final bool isExpanded;
  final VoidCallback? onExpandChanged;
  final int? tmdbId;
  final bool isTV;
  final bool isCompact;
  final String? locale;

  const StreamingOptionsWidget({
    super.key,
    required this.streamingOptions,
    this.isExpanded = false,
    this.onExpandChanged,
    this.tmdbId,
    this.isTV = false,
    this.isCompact = false,
    this.locale,
  });

  @override
  State<StreamingOptionsWidget> createState() => _StreamingOptionsWidgetState();
}

class _StreamingOptionsWidgetState extends State<StreamingOptionsWidget>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    if (_isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streamingOptions.isEmpty) {
      return _buildNoStreamingAvailable(context);
    }

    final grouped = _groupByType(widget.streamingOptions);
    final merged = _mergeProviders(grouped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, merged),
        ClipRect(
          child: SizeTransition(
            sizeFactor: _heightAnimation,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStreamingGrid(context, merged),
                  const SizedBox(height: 12),
                  _buildJustWatchAttribution(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, List<StreamingOption>> merged) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
          if (_isExpanded) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
          widget.onExpandChanged?.call();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 20,
                          child: Image.asset(
                            'assets/images/justwatch_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Where to watch',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (!widget.isCompact && !_isExpanded) ...[
                      const SizedBox(height: 6),
                      _buildCompactSummary(context, merged),
                    ],
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.expand_more,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSummary(BuildContext context, Map<String, List<StreamingOption>> merged) {
    final counts = <String>[];
    if (merged.containsKey('Stream')) {
      counts.add('${merged['Stream']!.length} Stream');
    }
    if (merged.containsKey('Free')) {
      counts.add('${merged['Free']!.length} Free');
    }
    if (merged.containsKey('Buy or Rent')) {
      counts.add('${merged['Buy or Rent']!.length} Buy or Rent');
    } else {
      if (merged.containsKey('Rent')) {
        counts.add('${merged['Rent']!.length} Rent');
      }
      if (merged.containsKey('Buy')) {
        counts.add('${merged['Buy']!.length} Buy');
      }
    }

    return Text(
      counts.join(' • '),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildStreamingGrid(
    BuildContext context,
    Map<String, List<StreamingOption>> merged,
  ) {
    // Order: Free, Stream, Buy or Rent (or Rent/Buy separately)
    final orderedKeys = <String>[];
    if (merged.containsKey('Free')) orderedKeys.add('Free');
    if (merged.containsKey('Stream')) orderedKeys.add('Stream');
    if (merged.containsKey('Buy or Rent')) {
      orderedKeys.add('Buy or Rent');
    } else {
      if (merged.containsKey('Rent')) orderedKeys.add('Rent');
      if (merged.containsKey('Buy')) orderedKeys.add('Buy');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: orderedKeys.asMap().entries.map((entry) {
        final index = entry.key;
        final key = entry.value;
        final options = merged[key]!;
        
        IconData icon;
        if (key == 'Stream') {
          icon = Icons.subscriptions;
        } else if (key == 'Free') {
          icon = Icons.free_breakfast;
        } else if (key == 'Buy or Rent' || key == 'Buy') {
          icon = Icons.shopping_bag;
        } else {
          icon = Icons.local_movies;
        }

        return Column(
          children: [
            if (index > 0) const SizedBox(height: 12),
            _buildStreamingTypeRow(context, key, options, icon),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStreamingTypeRow(
    BuildContext context,
    String typeLabel,
    List<StreamingOption> options,
    IconData icon,
  ) {
    // Split label on "or" for wrapped display - wrap AFTER "or", not before
    final labelParts = typeLabel.split(' or ');
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed-width label column (icon + text, potentially wrapped)
        SizedBox(
          width: 80, // Fixed width to align all icon rows
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      labelParts.length > 1 ? '${labelParts[0]} or' : labelParts[0],
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              // Show second part on next line if present
              // Indented to align with text above (icon 18px + spacing 8px = 26px)
              if (labelParts.length > 1) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    labelParts[1],
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Provider icons - aligned to top
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            runAlignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: options.map((option) => _buildProviderIcon(context, option)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderIcon(BuildContext context, StreamingOption option) {
    return Tooltip(
      message: option.providerName,
      preferBelow: false,
      verticalOffset: -40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchTmdbWatchPage(context, option),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: option.logoPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: CachedNetworkImage(
                      imageUrl: option.logoPath!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.play_circle_outline, size: 18),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.play_circle_outline, size: 18),
                      ),
                    ),
                  )
                : Icon(
                    Icons.play_circle_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildJustWatchAttribution(BuildContext context) {
    return InkWell(
      onTap: () => _launchJustWatch(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              Text(
                'Provider data powered by',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                height: 16,
                child: Image.asset(
                  'assets/images/justwatch_long.png',
                  fit: BoxFit.contain,
                  color: _getJustWatchLogoColor(context),
                  colorBlendMode: BlendMode.srcIn,
                  semanticLabel: 'JustWatch',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getJustWatchLogoColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? Colors.amber : Colors.amber.shade700;
  }

  Widget _buildNoStreamingAvailable(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Streaming options not available in your region',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<StreamingType, List<StreamingOption>> _groupByType(List<StreamingOption> options) {
    final grouped = <StreamingType, List<StreamingOption>>{};
    for (final option in options) {
      grouped.putIfAbsent(option.type, () => []).add(option);
    }
    return grouped;
  }

  Map<String, List<StreamingOption>> _mergeProviders(
    Map<StreamingType, List<StreamingOption>> grouped,
  ) {
    final merged = <String, List<StreamingOption>>{};

    if (grouped.containsKey(StreamingType.subscription)) {
      merged['Stream'] = grouped[StreamingType.subscription]!;
    }

    if (grouped.containsKey(StreamingType.free)) {
      merged['Free'] = grouped[StreamingType.free]!;
    }

    final rentOptions = grouped[StreamingType.rent] ?? [];
    final buyOptions = grouped[StreamingType.buy] ?? [];

    if (rentOptions.isNotEmpty && buyOptions.isNotEmpty) {
      // Check if they have the same providers
      final rentProviders = rentOptions.map((o) => o.providerId).toSet();
      final buyProviders = buyOptions.map((o) => o.providerId).toSet();

      if (rentProviders.length == buyProviders.length &&
          rentProviders.every((p) => buyProviders.contains(p))) {
        // Same providers, merge them
        merged['Buy or Rent'] = [...rentOptions];
      } else {
        // Different providers, keep separate
        if (rentOptions.isNotEmpty) merged['Rent'] = rentOptions;
        if (buyOptions.isNotEmpty) merged['Buy'] = buyOptions;
      }
    } else {
      if (rentOptions.isNotEmpty) merged['Rent'] = rentOptions;
      if (buyOptions.isNotEmpty) merged['Buy'] = buyOptions;
    }

    return merged;
  }

  void _launchTmdbWatchPage(BuildContext context, StreamingOption? option) {
    if (widget.tmdbId == null) {
      debugPrint('[StreamingOptionsWidget] TMDB ID not available');
      return;
    }

    // Get the watch link from the first streaming option if available
    String? watchLink;
    if (option?.watchLink != null) {
      watchLink = option!.watchLink;
    } else if (widget.streamingOptions.isNotEmpty && widget.streamingOptions.first.watchLink != null) {
      watchLink = widget.streamingOptions.first.watchLink;
    }

    ExternalNavigationUtils.launchTmdbWatchPage(
      context,
      tmdbId: widget.tmdbId!,
      isTV: widget.isTV,
      watchLink: watchLink,
      locale: widget.locale,
    );
  }

  void _launchJustWatch(BuildContext context) {
    ExternalNavigationUtils.launchJustWatch(context);
  }
}
