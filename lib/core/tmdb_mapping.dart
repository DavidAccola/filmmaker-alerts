class TmdbMapping {
  static String mapTmdbDeptToRole(String dept, {String? job}) {
    // Priority: Specific job mapping if provided
    if (job != null) {
      if (job == 'Director' || job == 'Director (TV)') return 'Director';
      if (job == 'Writer' || job == 'Screenplay' || job == 'Story') return 'Writer';
      if (job == 'Producer' || job == 'Executive Producer') return 'Production';
      if (job == 'Creator') return 'Creator';
    }

    // Department mapping
    if (dept == 'Directing' || dept == 'Director') return 'Director';
    if (dept == 'Writing' || dept == 'Writer') return 'Writer';
    if (dept == 'Production' || dept == 'Producer' || dept == 'Executive Producer') return 'Production';
    if (dept == 'Acting' || dept == 'Actor') return 'Actor';
    if (dept == 'Creator') return 'Creator';
    
    return dept;
  }
}
