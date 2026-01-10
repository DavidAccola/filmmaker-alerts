import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/contributor_detail.dart';

class StreamingOptionsWidget extends StatefulWidget {
  final List<StreamingOption> streamingOptions;
  final bool isExpanded;
  final VoidCallback? onExpandChanged;

  const StreamingOptionsWidget({
    super.key,
    required this.streamingOptions,
    this.isExpanded = false,
    this.onExpandChanged,
  });

  @override
  State<StreamingOptionsWidget> createState() => _StreamingOptionsWidgetState();
}

class _StreamingOptionsWidgetState extends State<StreamingOptionsWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streamingOptions.isEmpty) {
      return _buildNoStreamingAvailable(context);
    }

    // Group options by type
    final grouped = _groupByType(widget.streamingOptions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, grouped),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          _buildStreamingOptions(context, grouped),
          const SizedBox(height: 12),
          _buildJustWatchAttribution(context),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Map<StreamingType, List<StreamingOption>> grouped) {
    final subscriptionCount = grouped[StreamingType.subscription]?.length ?? 0;
    final rentCount = grouped[StreamingType.rent]?.length ?? 0;
    final buyCount = grouped[StreamingType.buy]?.length ?? 0;
    final freeCount = grouped[StreamingType.free]?.length ?? 0;

    final summary = <String>[];
    if (subscriptionCount > 0) summary.add('$subscriptionCount Subscription');
    if (rentCount > 0) summary.add('$rentCount Rent');
    if (buyCount > 0) summary.add('$buyCount Buy');
    if (freeCount > 0) summary.add('$freeCount Free');

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
        widget.onExpandChanged?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Streaming Options',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary.join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingOptions(
    BuildContext context,
    Map<StreamingType, List<StreamingOption>> grouped,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grouped[StreamingType.subscription] != null)
          _buildStreamingTypeSection(
            context,
            'Subscription',
            grouped[StreamingType.subscription]!,
          ),
        if (grouped[StreamingType.free] != null) ...[
          const SizedBox(height: 12),
          _buildStreamingTypeSection(
            context,
            'Free',
            grouped[StreamingType.free]!,
          ),
        ],
        if (grouped[StreamingType.rent] != null) ...[
          const SizedBox(height: 12),
          _buildStreamingTypeSection(
            context,
            'Rent',
            grouped[StreamingType.rent]!,
          ),
        ],
        if (grouped[StreamingType.buy] != null) ...[
          const SizedBox(height: 12),
          _buildStreamingTypeSection(
            context,
            'Buy',
            grouped[StreamingType.buy]!,
          ),
        ],
      ],
    );
  }

  Widget _buildStreamingTypeSection(
    BuildContext context,
    String typeLabel,
    List<StreamingOption> options,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          typeLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((option) => _buildProviderButton(context, option)).toList(),
        ),
      ],
    );
  }

  Widget _buildProviderButton(BuildContext context, StreamingOption option) {
    return GestureDetector(
      onTap: () => _launchStreamingLink(option.deepLink),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.logoPath != null)
              SizedBox(
                width: 24,
                height: 24,
                child: CachedNetworkImage(
                  imageUrl: option.logoPath!,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(Icons.play_circle_outline, size: 20),
                ),
              )
            else
              const Icon(Icons.play_circle_outline, size: 20),
            const SizedBox(width: 8),
            Text(
              option.providerName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJustWatchAttribution(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Powered by ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          GestureDetector(
            onTap: () => _launchJustWatchLink(),
            child: Text(
              'JustWatch',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStreamingAvailable(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Text(
        'Streaming options not available',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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

  void _launchStreamingLink(String url) {
    debugPrint('[StreamingOptionsWidget] Opening streaming link: $url');
    // TODO: Implement URL launching using url_launcher package
  }

  void _launchJustWatchLink() {
    debugPrint('[StreamingOptionsWidget] Opening JustWatch');
    // TODO: Implement URL launching to JustWatch homepage
  }
}
