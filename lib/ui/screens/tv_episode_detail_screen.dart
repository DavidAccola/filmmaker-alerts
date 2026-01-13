import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/tv_detail.dart';
import '../../data/models/preferences.dart';
import '../../data/models/movie_detail.dart';
import 'contributor_detail_screen.dart';
import '../../data/models/contributor.dart';
import '../../logic/work_sorting_logic.dart';
import '../common/shelf_with_arrows.dart';
import '../common/external_navigation_utils.dart';
import '../../providers/providers.dart';
import '../../core/tmdb_mapping.dart';
import '../common/expandable_synopsis.dart';
import '../common/runtime_display.dart';
import '../common/adaptive_tooltip_text.dart';

class TvEpisodeDetailScreen extends ConsumerStatefulWidget {
  final int showId;
  final int seasonNumber;
  final int episodeNumber;
  final String? showName;

  const TvEpisodeDetailScreen({
    super.key,
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.showName,
  });

  @override
  ConsumerState<TvEpisodeDetailScreen> createState() => _TvEpisodeDetailScreenState();
}

class _TvEpisodeDetailScreenState extends ConsumerState<TvEpisodeDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesProvider);
    final episodeDetailAsync = ref.watch(tvEpisodeDetailProvider((
      showId: widget.showId,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
    )));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showName ?? 'Episode Details'),
      ),
      body: prefsAsync.when(
        data: (prefs) => episodeDetailAsync.when(
          data: (episodeDetail) => episodeDetail != null 
              ? _buildContent(prefs, episodeDetail)
              : _buildErrorState('Episode details not available'),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState('Error: $error'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState('Error: $error'),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tv, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Preferences prefs, TvEpisodeDetail episodeDetail) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEpisodeHeader(episodeDetail, prefs),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Section
                Text(
                  'Overview',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ExpandableSynopsis(
                  synopsis: episodeDetail.overview ?? '',
                  isEpisode: true,
                  isUpcoming: episodeDetail.airDate?.isAfter(DateTime.now()) ?? true,
                ),
                const SizedBox(height: 24),

                // Episode Crew (Now Above Cast)
                _buildKeyCrew(episodeDetail),
                
                if (episodeDetail.crew.isNotEmpty)
                  const SizedBox(height: 24),

                // Series Regulars
                if (episodeDetail.mainCast.isNotEmpty)
                  _buildCastSection('Series Regulars', episodeDetail.mainCast),
                
                if (episodeDetail.mainCast.isNotEmpty)
                  const SizedBox(height: 24),

                // Guest Stars
                if (episodeDetail.guestStars.isNotEmpty)
                  _buildCastSection('Guest Stars', episodeDetail.guestStars),
                
                if (episodeDetail.guestStars.isNotEmpty)
                  const SizedBox(height: 24),
                
                _buildExternalLinks(episodeDetail),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeHeader(TvEpisodeDetail episodeDetail, Preferences prefs) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Episode Thumbnail (Left)
          SizedBox(
            width: 140, // Slightly wider for 16:9 thumb
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: episodeDetail.stillPath != null
                  ? CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w300${episodeDetail.stillPath}',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.tv, size: 32),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.tv, size: 32),
                    ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Episode Info (Right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                  'S${episodeDetail.seasonNumber} E${episodeDetail.episodeNumber}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                AdaptiveTooltipText(
                  episodeDetail.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20, // Slightly smaller than movie title potentially
                  ),
                  maxLines: 2,
                ),
                 const SizedBox(height: 4),
                AdaptiveTooltipText(
                   episodeDetail.showName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (episodeDetail.airDate != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(episodeDetail.airDate!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    if (episodeDetail.airDate != null && episodeDetail.runtime != null && episodeDetail.runtime! > 0)
                       Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), 
                          child: Text("•", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                       ),
                    if (episodeDetail.runtime != null && episodeDetail.runtime! > 0)
                      RuntimeDisplay(
                        runtime: episodeDetail.runtime!,
                        isUpcoming: episodeDetail.airDate?.isAfter(DateTime.now()) ?? true,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                 if (episodeDetail.tmdbRating != null && episodeDetail.tmdbRating! > 0 && !(prefs.hideRatingsInDetails ?? false))
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            episodeDetail.tmdbRating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeBanner(TvEpisodeDetail episodeDetail) {
    final theme = Theme.of(context);
    
    return AspectRatio(
      aspectRatio: 2.35 / 1, // Wider Cinemascope-style aspect ratio to save vertical space
      child: Container(
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest,
        child: episodeDetail.stillPath != null
            ? CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w780${episodeDetail.stillPath}',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter, // Often faces/action are in top/center
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.tv, size: 48),
              )
            : const Icon(Icons.tv, size: 48),
      ),
    );
  }

  Widget _buildCastSection(String title, List<CastMember> cast) {
    final theme = Theme.of(context);
    final sortedCast = WorkSortingLogic.sortCast(cast);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ShelfWithArrows(
          height: 120,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: sortedCast.length,
            itemBuilder: (context, index) {
              final member = sortedCast[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: _ContributorHoverCircle(
                  tmdbId: member.tmdbId,
                  name: member.name,
                  profilePath: member.profilePath,
                  subtitle: '', // Character is shown in character field? No, member.character
                  character: member.character,
                  isFollowed: member.isFollowed,
                  radius: 30,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContributorDetailScreen(
                          contributor: Contributor(
                            tmdbId: member.tmdbId,
                            name: member.name,
                            type: ContributorType.person,
                            profilePath: member.profilePath,
                            notifyForDepartments: [],
                            availableDepartments: [],
                            knownFor: '',
                          ),
                        ),
                      ),
                    );
                  },
                  onFollow: () {
                    debugPrint('Follow cast: ${member.name}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeyCrew(TvEpisodeDetail episodeDetail) {
    final theme = Theme.of(context);
    final sortedCrew = WorkSortingLogic.groupAndSortCrew(episodeDetail.crew);
    
    if (sortedCrew.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Episode Crew',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ShelfWithArrows(
          height: 120,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: sortedCrew.length,
            itemBuilder: (context, index) {
              final member = sortedCrew[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: _ContributorHoverCircle(
                  tmdbId: member.tmdbId,
                  name: member.name,
                  profilePath: member.profilePath,
                  subtitle: member.job,
                  isFollowed: member.isFollowed,
                  radius: 30,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContributorDetailScreen(
                          contributor: Contributor(
                            tmdbId: member.tmdbId,
                            name: member.name,
                            type: ContributorType.person,
                            profilePath: member.profilePath,
                            notifyForDepartments: [],
                            availableDepartments: [],
                            knownFor: '',
                          ),
                        ),
                      ),
                    );
                  },
                  onFollow: () {
                    debugPrint('Follow crew: ${member.name}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExternalLinks(TvEpisodeDetail episodeDetail) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ExternalNavigationUtils.launchTmdbTitle(
                context,
                tmdbId: episodeDetail.showId,
                isTV: true,
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('View Show on TMDB'),
          ),
        ),
      ],
    );
  }
}

class _ContributorHoverCircle extends StatefulWidget {
  final int tmdbId;
  final String name;
  final String? profilePath;
  final String subtitle;
  final String? character;
  final bool isFollowed;
  final double radius;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  const _ContributorHoverCircle({
    required this.tmdbId,
    required this.name,
    this.profilePath,
    required this.subtitle,
    this.character,
    required this.isFollowed,
    required this.radius,
    required this.onTap,
    required this.onFollow,
  });

  @override
  State<_ContributorHoverCircle> createState() => _ContributorHoverCircleState();
}

class _ContributorHoverCircleState extends State<_ContributorHoverCircle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.radius + 10),
        child: SizedBox(
          width: widget.radius * 2 + 20,
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: widget.radius,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: widget.profilePath != null
                        ? CachedNetworkImageProvider('https://image.tmdb.org/t/p/w200${widget.profilePath}')
                        : null,
                    child: widget.profilePath == null ? const Icon(Icons.person) : null,
                  ),
                  
                  // Hover Mask + Center Follow Button
                  AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: widget.radius * 2,
                      height: widget.radius * 2,
                      decoration: BoxDecoration(
                         color: Colors.blue.withOpacity(0.4),
                         shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            widget.isFollowed ? Icons.remove_circle : Icons.add_circle,
                            size: 24,
                            color: Colors.white,
                          ),
                          onPressed: widget.onFollow,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: widget.isFollowed ? 'Unfollow' : 'Follow',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AdaptiveTooltipText(
                widget.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: widget.isFollowed ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (widget.subtitle.isNotEmpty)
                AdaptiveTooltipText(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
               if (widget.character != null && widget.character!.isNotEmpty && widget.character != widget.subtitle)
                AdaptiveTooltipText(
                  widget.character!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
