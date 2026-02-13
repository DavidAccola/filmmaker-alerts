import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../data/models/tv_detail.dart';
import '../../data/models/preferences.dart';
import '../../data/models/movie_detail.dart';
import 'contributor_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import 'tv_season_detail_screen.dart';
import '../../data/models/contributor.dart';
import '../../logic/work_sorting_logic.dart';
import '../common/shelf_with_arrows.dart';
import '../common/external_navigation_utils.dart';
import '../../providers/providers.dart';
import '../common/expandable_synopsis.dart';
import '../common/runtime_display.dart';
import '../common/adaptive_tooltip_text.dart';
import '../common/contributor_hover_card.dart';
import '../common/snackbar_utils.dart';
import '../common/department_selection_dialog.dart';
import '../common/tv_breadcrumb.dart';
import '../common/streaming_options_widget.dart';

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
  void initState() {
    super.initState();
  }
  
  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesProvider);
    final episodeDetailAsync = ref.watch(tvEpisodeDetailProvider((
      showId: widget.showId,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
    )));
    final showDetailAsync = ref.watch(tvShowDetailProvider(widget.showId));
    
    return Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            return episodeDetailAsync.when(
              data: (episodeDetail) {
                if (episodeDetail == null) {
                  return const Text('Episode Details');
                }
                
                return TvBreadcrumb(
                  items: [
                    BreadcrumbItem(
                      label: widget.showName ?? 'Show',
                      isClickable: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TvShowDetailScreen(
                              showId: widget.showId,
                              showTitle: widget.showName,
                            ),
                          ),
                        );
                      },
                    ),
                    BreadcrumbItem(
                      label: 'Season ${widget.seasonNumber}',
                      isClickable: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TvSeasonDetailScreen(
                              showId: widget.showId,
                              seasonNumber: widget.seasonNumber,
                              showName: widget.showName ?? 'Show',
                            ),
                          ),
                        );
                      },
                    ),
                    BreadcrumbItem(
                      label: 'Episode ${widget.episodeNumber}: ${episodeDetail.name}',
                      isClickable: false,
                    ),
                  ],
                  maxWidth: constraints.maxWidth - 100,
                );
              },
              loading: () => const Text('Episode Details'),
              error: (e, s) => const Text('Episode Details'),
            );
          },
        ),
      ),
      body: prefsAsync.when(
        data: (prefs) => episodeDetailAsync.when(
          data: (episodeDetail) => episodeDetail != null 
              ? showDetailAsync.when(
                  data: (showDetail) => _buildContent(prefs, episodeDetail, showDetail),
                  loading: () => _buildContent(prefs, episodeDetail, null),
                  error: (e, s) => _buildContent(prefs, episodeDetail, null),
                )
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
          const Icon(Symbols.tv_gen, size: 64, color: Colors.grey),
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

  Widget _buildContent(Preferences prefs, TvEpisodeDetail episodeDetail, TvShowDetail? showDetail) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEpisodeHeader(episodeDetail, prefs, showDetail),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
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

  Widget _buildEpisodeHeader(TvEpisodeDetail episodeDetail, Preferences prefs, TvShowDetail? showDetail) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 800;
          
          if (isWideScreen) {
            // Wide screen layout: thumbnail + info on left, streaming on right
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Thumbnail and basic info
                Expanded(
                  flex: 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Episode Thumbnail
                      SizedBox(
                        width: 140,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: episodeDetail.stillPath != null
                              ? CachedNetworkImage(
                                  imageUrl: 'https://image.tmdb.org/t/p/w300${episodeDetail.stillPath}',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => const Icon(Symbols.tv_gen, size: 32),
                                )
                              : Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Symbols.tv_gen, size: 32),
                                ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Episode Info
                      Expanded(
                        child: _buildEpisodeInfo(episodeDetail, prefs),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // Right side: Streaming options (always show, even when empty)
                if (showDetail != null)
                  SizedBox(
                    width: 350,
                    child: StreamingOptionsWidget(
                      streamingOptions: showDetail.streamingOptions,
                      tmdbId: showDetail.tmdbId,
                      isTV: true,
                      isCompact: true,
                      locale: prefs.streamingCountry,
                      title: showDetail.name,
                      releaseDate: showDetail.firstAirDate,
                    ),
                  ),
              ],
            );
          } else {
            // Narrow screen layout: traditional stacked layout
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Episode Thumbnail
                    SizedBox(
                      width: 140,
                      height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: episodeDetail.stillPath != null
                            ? CachedNetworkImage(
                                imageUrl: 'https://image.tmdb.org/t/p/w300${episodeDetail.stillPath}',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => const Icon(Symbols.tv_gen, size: 32),
                              )
                            : Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Symbols.tv_gen, size: 32),
                              ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Episode Info
                    Expanded(
                      child: _buildEpisodeInfo(episodeDetail, prefs),
                    ),
                  ],
                ),
                
                // Streaming options below on small screens (always show, even when empty)
                if (showDetail != null) ...[
                  const SizedBox(height: 16),
                  StreamingOptionsWidget(
                    streamingOptions: showDetail.streamingOptions,
                    tmdbId: showDetail.tmdbId,
                    isTV: true,
                    isCompact: true,
                    locale: prefs.streamingCountry,
                    title: showDetail.name,
                    releaseDate: showDetail.firstAirDate,
                  ),
                ],
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildEpisodeInfo(TvEpisodeDetail episodeDetail, Preferences prefs) {
    return Column(
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
            fontSize: 20,
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
          height: 175,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: sortedCast.length,
            itemBuilder: (context, index) {
              final member = sortedCast[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ContributorHoverCard(
                  tmdbId: member.tmdbId,
                  name: member.name,
                  profilePath: member.profilePath,
                  subtitle: member.character,
                  character: member.character,
                  isFollowed: member.isFollowed,
                  // radius: 30, // Removed
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
                  onFollow: () async {
                    await _handleFollowPerson(member, ref);
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
          height: 175,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: sortedCrew.length,
            itemBuilder: (context, index) {
              final member = sortedCrew[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ContributorHoverCard(
                  tmdbId: member.tmdbId,
                  name: member.name,
                  profilePath: member.profilePath,
                  subtitle: member.job,
                  isFollowed: member.isFollowed,
                  // radius: 30, // Removed
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
                  onFollow: () async {
                    await _handleFollowPerson(member, ref);
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
    return Consumer(
      builder: (context, ref, child) {
        final prefsAsync = ref.watch(preferencesProvider);
        return prefsAsync.when(
          data: (prefs) {
            final movieDetailsPreference = prefs.movieDetailsPreference ?? 'both';
            final brightness = Theme.of(context).brightness;
            
            // Determine which links to show based on preference
            final showTmdb = movieDetailsPreference == 'tmdb' || movieDetailsPreference == 'both';
            final showImdb = movieDetailsPreference == 'imdb' || movieDetailsPreference == 'both';
            
            // Get IMDb ID from the TV show cache (episodes don't have their own IMDb IDs)
            String? imdbId;
            bool hasImdbId = false;
            if (showImdb) {
              final tvCacheRepo = ref.read(tvCacheRepositoryProvider);
              final tvShow = tvCacheRepo.getShow(episodeDetail.showId);
              imdbId = tvShow?.imdbId;
              hasImdbId = imdbId != null && imdbId.isNotEmpty;
            }
            
            if (!showTmdb && !showImdb) {
              return const SizedBox.shrink();
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (showTmdb) ...[
                        Tooltip(
                          message: 'View ${episodeDetail.name} on TMDB',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => ExternalNavigationUtils.launchTmdbEpisode(
                                context,
                                showId: episodeDetail.showId,
                                seasonNumber: episodeDetail.seasonNumber,
                                episodeNumber: episodeDetail.episodeNumber,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.asset(
                                    'assets/images/tmdb_square.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      child: const Icon(Symbols.movie),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (showImdb && hasImdbId) ...[
                        Tooltip(
                          message: 'View ${episodeDetail.showName} on IMDb',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => ExternalNavigationUtils.launchImdbTitle(
                                context,
                                imdbId: imdbId!,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.asset(
                                    brightness == Brightness.light
                                        ? 'assets/images/imdb_square_gold.png'
                                        : 'assets/images/imdb_square_black.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFFF5C518),
                                      child: const Center(
                                        child: Text(
                                          'I',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _handleFollowPerson(dynamic member, WidgetRef ref) async {
    try {
      final contributorLogic = ref.read(contributorLogicProvider);
      final repo = ref.read(contributorRepositoryProvider);
      
      // Determine knownFor based on member type (CastMember vs CrewMember)
      String knownFor = '';
      if (member is CastMember) {
        knownFor = 'Actor';
      } else if (member is CrewMember) {
        // For crew, use their primary department as knownFor
        knownFor = member.department;
      }
      
      final sparseContributor = Contributor(
        tmdbId: member.tmdbId,
        name: member.name,
        type: ContributorType.person,
        profilePath: member.profilePath,
        notifyForDepartments: [],
        availableDepartments: [],
        knownFor: knownFor,
      );

      final availableDepts = await contributorLogic.getAvailableDepartments(sparseContributor);
      
      if (!mounted) return;

      final success = await contributorLogic.addEnrichedContributor(
        sparseContributor,
        overrideAvailableDepts: availableDepts,
      );

      // Always invalidate episode detail to refresh isFollowed status
      if (mounted) {
        ref.invalidate(tvEpisodeDetailProvider((showId: widget.showId, seasonNumber: widget.seasonNumber, episodeNumber: widget.episodeNumber)));
      }

      if (success && mounted) {
        ref.invalidate(contributorsProvider);
        
        final prefs = ref.read(preferencesRepositoryProvider).getPreferences();
        final selectedDepts = availableDepts
            .where((d) => prefs.effectiveDefaultDepartments.contains(d) || d == knownFor)
            .toList();

        showSuccessSnackBar(
          context,
          contributor: sparseContributor,
          roles: selectedDepts,
          availableRoles: availableDepts,
          onChange: () async {
            // Show the department selection dialog
            if (mounted) {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => DepartmentSelectionDialog(
                  name: sparseContributor.name,
                  availableDepartments: availableDepts,
                  initialSelectedDepartments: selectedDepts,
                  defaultDepartments: prefs.effectiveDefaultDepartments,
                  initialAllRolesSelected: false,
                  allowTrueAll: prefs.autoFollowNewRoles ?? true,
                ),
              );

              if (result != null && mounted) {
                final newRoles = result['roles'] as List<String>;
                
                // Fetch the actual contributor from the repository to preserve followedAt
                final existingContributor = ref.read(contributorRepositoryProvider).getContributor(sparseContributor.tmdbId);
                
                if (existingContributor != null) {
                  await contributorLogic.updateContributorRoles(existingContributor, newRoles);
                  ref.invalidate(contributorsProvider);
                  ref.invalidate(tvEpisodeDetailProvider((showId: widget.showId, seasonNumber: widget.seasonNumber, episodeNumber: widget.episodeNumber)));
                  
                  if (mounted) {
                    showSimpleSnackBar(context, 'Updated ${sparseContributor.name} to follow ${newRoles.join(", ")}', duration: const Duration(seconds: 3));
                  }
                }
              }
            }
          },
        );
      } else if (mounted) {
        // Person already followed - show new snackbar with unfollow option
        showAlreadyFollowedSnackBar(
          context,
          contributorName: member.name,
          onUnfollow: () async {
            await repo.removeContributor(member.tmdbId);
            ref.invalidate(contributorsProvider);
            ref.invalidate(tvEpisodeDetailProvider((showId: widget.showId, seasonNumber: widget.seasonNumber, episodeNumber: widget.episodeNumber)));
            
            if (mounted) {
              showRemovalSnackBar(
                context,
                message: 'Unfollowed ${member.name}',
                onUndo: () async {
                  final existingContributor = repo.getContributor(member.tmdbId);
                  if (existingContributor != null) {
                    await repo.addContributor(existingContributor);
                    ref.invalidate(contributorsProvider);
                    ref.invalidate(tvEpisodeDetailProvider((showId: widget.showId, seasonNumber: widget.seasonNumber, episodeNumber: widget.episodeNumber)));
                  }
                },
              );
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        showSimpleSnackBar(context, 'Error: $e');
      }
    }
  }
}

// Local _ContributorHoverCircle removed. Using common/contributor_hover_card.dart
