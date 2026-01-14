class CrewConstants {
  // Directing - Stage 1
  static const List<String> directingStage1 = [
    'Director',
    'Directed By',
    'Series Director',
    'Co-Director',
    'Special Guest Director',
    'Assistant Director',
    'First Assistant Director',
    '1st Assistant Director',
    'First Assistant Director (Prep)',
    'Second Assistant Director',
    '2nd Assistant Director',
    'Second Second Assistant Director',
    'Third Assistant Director',
    '3rd Assistant Director',
    'Additional Second Assistant Director',
    'Additional Third Assistant Director',
    'Assistant Director Trainee',
    'First Assistant Director Trainee',
    'Second Assistant Director Trainee',
  ];

  // Writing - Stage 1
  static const List<String> writingStage1 = [
    'Original Series Creator',
    'Original Screenplay',
    'Original Film Writer',
    'Original Story',
    'Original Concept',
    'Writer',
    'Written by',
    'Screenwriter',
    'Screenplay',
    'Screenplay by',
    'Teleplay',
    'Teleplay by',
    'Co-Writer',
    'Screenstory',
    'Story',
    'Story by',
    'Head of Story',
    'Story Developer',
    'Scenario Writer',
  ];

  // Production - Stage 1
  static const List<String> productionStage1 = [
    'Producer',
    'Produced by', // Normalized typically often just 'Producer' but keeping exact
    'Executive Producer',
    'Executive In Charge Of Production',
    'Head of Production',
    'Line Producer',
    'Co-Producer',
    'Executive Co-Producer',
    'Co-Executive Producer',
    'Supervising Producer',
    'Coordinating Producer',
    'Delegated Producer',
    'Development Producer',
    'Development Manager',
  ];

  // Directing - Stage 2
  static const List<String> directingStage2 = [
    'Second Unit Director',
    'Insert Unit Director',
    'Stage Director',
    'Action Director',
    'Field Director',
    'Crowd Assistant Director',
    'Insert Unit First Assistant Director',
    'Second Unit First Assistant Director',
    'Continuity',
    'Layout',
    // Others alphabetical
  ];

  // Writing - Stage 2
  static const List<String> writingStage2 = [
    'Executive Story Editor',
    'Senior Story Editor',
    'Story Editor',
    'Junior Story Editor',
    'Script Editor',
    'Story Supervisor',
    'Story Manager',
    'Story Coordinator',
    'Storyboard',
    'Story Artist',
    'Story Consultant',
    'Script Consultant',
    'Dialogue',
    'Adaptation',
    'Characters',
    'Author',
    'Book',
    'Novel',
    'Short Story',
    'Theatre Play',
    'Opera',
    'Musical',
    'Lyricist',
    'Comic Book',
    'Graphic Novel',
    'Series Composition',
    'Staff Writer',
    'Writers\' Production',
    'Creative Producer',
    'Writers\' Assistant',
    'Assistant to Writers',
    'Idea',
    // Others alphabetical
  ];

  // Production - Stage 2
  static const List<String> productionStage2 = [
    'Producer\'s Assistant',
    'Assistant to Producers',
    'Supervising Producer', // Already in Stage 1? User listed it in both? Prioritize Stage 1 if duplicate.
    'Feature Finishing Producer',
    'Finishing Producer',
    'Post Producer',
    'Post Production Producer',
    'Executive In Charge Of Post Production',
    'Post Production Coordinator',
    'Post-Production Coordinator',
    'Post Production Technical Engineer',
    'Post Production Accountant',
    'Post Coordinator',
    'Additional Post-Production Supervisor',
    'Production Director',
    'Production Executive',
    'Production Manager',
    'Unit Production Manager',
    'Unit Manager',
    'Unit Swing',
    'Second Unit Location Manager',
    'Insert Unit Location Manager',
    'Location Manager',
    'Location Coordinator',
    'Location Assistant',
    'Location Production Assistant',
    'Assistant Location Manager',
    'Locale Casting Director',
    'Local Casting Director',
    'Local Casting',
    'Casting Director',
    'Casting Producer',
    'Casting',
    'Original Casting',
    'Background Casting Director',
    'Musical Casting',
    'Street Casting',
    'Casting Coordinator',
    'Casting Associate',
    'Casting Assistant',
    'Casting Researcher',
    'Assistant Extras Casting',
    'Extras Casting',
    'Extras Casting Coordinator',
    'Extras Casting Assistant',
    'Additional Casting',
    'Assistant Unit Manager',
    'Assistant Production Manager',
    'Production Supervisor',
    'Production Office Coordinator',
    'POC',
    'Production Coordinator',
    'Production Co-Ordinator',
    'First Assistant Production Coordinator',
    'Second Assistant Production Coordinator',
    'Trainee Production Coordinator',
    'Assistant Production Coordinator',
    'Production Trainee',
    'Production Assistant',
    'Production Runner',
    'Production Secretary',
    'Production Driver',
    'Production Accountant',
    'Key Accountant',
    'First Assistant Accountant',
    'Second Assistant Accountant',
    'Assistant Accountant',
    'Payroll Accountant',
    'Accounting Supervisor',
    'Accounting Clerk Assistant',
    'Accounting Trainee',
    'Controller',
    'Finance',
    'Business Affairs Coordinator',
    'Contract Manager',
    'Consulting Accountant',
    'Attorney',
    'Key Production Assistant',
    'Key Set Production Assistant',
    'Key Art Production Assistant',
    'Art Department Production Assistant',
    'Grip Production Assistant',
    'Key Grip Production Assistant',
    'Back-up Set Production Assistant',
    'Back-up Truck Production Assistant',
    'Truck Production Assistant',
    'Character Technical Supervisor',
    'Production Designer',
    'Script Researcher',
    'Researcher',
    'Research Assistant',
    'Head of Programming',
    'Head of Research',
    'Broadcast Producer',
    'Publicist',
    'Travel Coordinator',
    'Data Management Technician',
    'Director of Operations',
    'General Manager',
    'Human Resources',
    'Administration',
    'Executive Assistant',
    'Executive Producer\'s Assistant',
    'Production Consultant',
    'Consulting Producer',
    'Executive Consultant',
    'Senior Executive Consultant',
    'Casting Consultant',
    'Additional Production Assistant',
    // Others alphabetical
  ];

  // Sound - Stage 1
  static const List<String> soundStage1 = [
    'Original Music Composer',
    'Composer',
    'Music',
    'Music by',
    'Music Composed by',
    'Music Score',
    'Original Score Composed by',
    'Original Score Music',
    'Original Score',
    'Original Music',
    'Additional Soundtrack',
    'Main Title Theme Composer',
    'Music Arranger',
    'Orchestrator',
    'Orchestration',
    'Songs',
  ];

  // Sound - Stage 2
  static const List<String> soundStage2 = [
    'Music Score Producer',
    'Music Producer',
    'Music Editor',
    'Supervising Music Editor',
    'Music Director',
    'Music Coordinator',
    'Music Supervisor',
    'Music Co-Supervisor',
    'Additional Music Supervisor',
    'Assistant Music Supervisor',
    'Music Supervision Assistant',
    'Music Sound Design and Processing',
    'Music Programmer',
    'Programming',
    'Keyboard Programmer',
    'Conductor',
    'Conducting',
    'Recording Supervision',
    'Theme Song Performance',
    'Playback Singer',
    'Vocals',
    'Vocal Coach',
    'Musician',
    'Music Consultant',
    'Scoring Mixer',
    'Dolby Consultant',
    'Supervising Sound Editor',
    'Sound Designer',
    'Sound Design',
    'Supervising Sound Effects Editor',
    'Sound Effects Designer',
    'Sound Effects Editor',
    'Effects Editor',
    'Sound Editor',
    'Sound Montage Associate',
    'Sound Post Supervisor',
    'Sound Post Production Coordinator',
    'Audio Post Coordinator',
    'Sound Re-Recording Mixer',
    'Re-Recording Mixer',
    'Re-Recording Engineer',
    'Additional Sound Re-Recording Mixer',
    'Additional Re-Recording Mixer',
    'Sound Re-Recording Assistant',
    'Sound Mix Technician',
    'Sound Mixer',
    'Production Sound Mixer',
    'Location Sound Mixer',
    'Location Sound Recordist',
    'Location Sound Assistant',
    'Boom Operator',
    'O.B. Sound',
    'Sound Recordist',
    'Sound Technical Supervisor',
    'Sound Engineer',
    'Engineer',
    'Assistant Sound Engineer',
    'Sound Assistant',
    'Sound Supervisor',
    'Sound Director',
    'Dialogue Editor',
    'Supervising Dialogue Editor',
    'ADR Supervisor',
    'Automated Dialogue Replacement Supervisor',
    'ADR Mixer',
    'Joint ADR Mixer',
    'ADR & Dubbing',
    'ADR Editor',
    'Automated Dialogue Replacement Editor',
    'Supervising ADR Editor',
    'Supervising Automated Dialogue Replacement Editor',
    'ADR Recording Engineer',
    'ADR Recordist',
    'ADR Engineer',
    'ADR Post Producer',
    'ADR Coordinator',
    'Loop Group Coordinator',
    'Foley Supervisor',
    'Foley',
    'Foley Artist',
    'Digital Foley Artist',
    'Foley Editor',
    'Foley Editing',
    'Foley Mixer',
    'Foley Recording Engineer',
    'Foley Recordist',
    'Assistant Foley Artist',
    'Assistant Dialogue Editor',
    'First Assistant Sound Editor',
    'Second Assistant Sound',
    'Apprentice Sound Editor',
    'Assistant Sound Editor',
    'Sound Effects',
    'Sound Montage Associate',
    'Sound Post Production Coordinator',
    'Sound Assistant',
    'Sound Mix Technician',
    'Scoring Mixer',
    'Recording Supervision',
    'Utility Sound',
    'Additional Production Sound Mixer',
    'Additional Sound Re-Recordist',
    'Additional Sound Re-Recording Mixer',
    'ADR Editor wastebasket',
    'Audio Post Coordinator',
    // Others alphabetical
  ];

  static bool isStage1(String department, String job) {
    switch (department) {
      case 'Directing':
        return directingStage1.contains(job);
      case 'Writing':
        return writingStage1.contains(job);
      case 'Production':
        return productionStage1.contains(job);
      case 'Sound':
        return soundStage1.contains(job);
      default:
        return false;
    }
  }

  static bool isStage2(String department, String job) {
    switch (department) {
      case 'Directing':
        return directingStage2.contains(job);
      case 'Writing':
        return writingStage2.contains(job);
      case 'Production':
        return productionStage2.contains(job);
      case 'Sound':
        return soundStage2.contains(job);
      default:
        return false;
    }
  }

  static int getRoleRank(String department, String job) {
    List<String> list1 = [];
    List<String> list2 = [];
    
    switch (department) {
      case 'Directing':
        list1 = directingStage1;
        list2 = directingStage2;
        break;
      case 'Writing':
        list1 = writingStage1;
        list2 = writingStage2;
        break;
      case 'Production':
        list1 = productionStage1;
        list2 = productionStage2;
        break;
      case 'Sound':
        list1 = soundStage1;
        list2 = soundStage2;
        break;
      default:
        return 9999;
    }

    int index1 = list1.indexOf(job);
    if (index1 != -1) return index1; // Stage 1 ranking (0 to N)

    int index2 = list2.indexOf(job);
    if (index2 != -1) return 1000 + index2; // Stage 2 ranking (starts at 1000)

    // For "Other" or unlisted roles
    if (job.toLowerCase().contains('other')) return 99999;

    return 5000; // Unlisted but in department (Alphabetical zone)
  }
}
