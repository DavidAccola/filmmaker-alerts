# Crew Sorting Logic
This document defines the logic for sorting crew members on detail screens.

The sorting is done in two stages:
1.  **Stage 1 Roles**: High-priority roles from specific departments are shown first.
2.  **Stage 2 Roles**: Lower-priority roles from those departments, and roles from all other departments, are shown next.

Within each stage, roles are sorted by their priority order as defined below. If multiple people have the same role, they are sorted alphabetically by name.

When a role is "Other", it should be displayed as "Other ([Department])" and appear last within its department group.

## Stage 1: Priority Departments

### Directing (Stage 1)
1.  Director
2.  Directed By
3.  Series Director
4.  Co-Director
5.  Special Guest Director
6.  Assistant Director
7.  First Assistant Director
8.  1st Assistant Director
9.  First Assistant Director (Prep)
10. Second Assistant Director
11. 2nd Assistant Director
12. Second Second Assistant Director
13. Third Assistant Director
14. 3rd Assistant Director
15. Additional Second Assistant Director
16. Additional Third Assistant Director
17. Assistant Director Trainee
18. First Assistant Director Trainee
19. Second Assistant Director Trainee

### Writing (Stage 1)
1.  Original Series Creator
2.  Original Screenplay
3.  Original Film Writer
4.  Original Story
5.  Original Concept
6.  Writer
7.  Written by
8.  Screenwriter
9.  Screenplay
10. Screenplay by
11. Teleplay
12. Teleplay by
13. Co-Writer
14. Screenstory
15. Story
16. Story by
17. Head of Story
18. Story Developer
19. Scenario Writer

### Production (Stage 1)
1.  Producer
2.  Produced by
3.  Executive Producer
4.  Executive In Charge Of Production
5.  Head of Production
6.  Line Producer
7.  Co-Producer
8.  Executive Co-Producer
9.  Co-Executive Producer
10. Supervising Producer
11. Coordinating Producer
12. Delegated Producer
13. Development Producer
14. Development Manager

## Stage 2: Secondary Department Roles & Other Departments

### Directing (Stage 2)
1.  Second Unit Director
2.  Insert Unit Director
3.  Stage Director
4.  Action Director
5.  Field Director
6.  Crowd Assistant Director
7.  Insert Unit First Assistant Director
8.  Second Unit First Assistant Director
9.  Continuity
10. Layout
11. [Any other Directing roles alphabetical]
12. Other

### Writing (Stage 2)
1.  Executive Story Editor
2.  Senior Story Editor
3.  Story Editor
4.  Junior Story Editor
5.  Script Editor
6.  Story Supervisor
7.  Story Manager
8.  Story Coordinator
9.  Storyboard
10. Story Artist
11. Story Consultant
12. Script Consultant
13. Dialogue
14. Adaptation
15. Characters
16. Author
17. Book
18. Novel
19. Short Story
20. Theatre Play
21. Opera
22. Musical
23. Lyricist
24. Comic Book
25. Graphic Novel
26. Series Composition
27. Staff Writer
28. Writers' Production
29. Creative Producer
30. Writers' Assistant
31. Assistant to Writers
32. Idea
33. [Any other Writing roles alphabetical]
34. Other

### Production (Stage 2)
*(Note: List includes various assistant, coordinator, casting, and management roles)*
1.  Producer's Assistant (alt. Assistant to Producers)
2.  Producer's Assistant
3.  Supervising Producer
4.  Feature Finishing Producer
5.  Finishing Producer
6.  Post Producer
7.  Post Production Producer
8.  Executive In Charge Of Post Production
9.  Post Production Coordinator (alt. Post-Production Coordinator)
10. Post Production Technical Engineer
11. Post Production Accountant
12. Post Coordinator
13. Additional Post-Production Supervisor
14. Production Director
15. Production Executive
16. Production Manager
17. Unit Production Manager
18. Unit Manager
19. Unit Swing
20. Second Unit Location Manager
21. Insert Unit Location Manager
22. Location Manager
23. Location Coordinator
24. Location Assistant
25. Location Production Assistant
26. Assistant Location Manager
27. Locale Casting Director pencil Local Casting Director
28. Local Casting
29. Casting Director
30. Casting Producer
31. Casting (alt. [City/Country] Casting by XXX)
32. Original Casting
33. Background Casting Director
34. Musical Casting
35. Street Casting
36. Local Casting
37. Casting Coordinator
38. Casting Associate
39. Casting Assistant
40. Casting Researcher
41. Assistant Extras Casting
42. Extras Casting
43. Extras Casting Coordinator
44. Extras Casting Assistant
45. Additional Casting
46. Assistant Unit Manager
47. Assistant Production Manager
48. Production Supervisor
49. Production Office Coordinator (alt. POC)
50. Production Coordinator (*alt. Production Co-Ordinator *)
51. First Assistant Production Coordinator
52. Second Assistant Production Coordinator
53. Trainee Production Coordinator
54. Assistant Production Coordinator
55. Production Trainee
56. Production Assistant
57. Production Runner
58. Production Secretary
59. Production Driver
60. Production Runner
61. Production Accountant
62. Production Accountant
63. Key Accountant
64. First Assistant Accountant
65. Second Assistant Accountant
66. Assistant Accountant
67. Payroll Accountant
68. Accounting Supervisor
69. Accounting Clerk Assistant
70. Accounting Trainee
71. Accounting Trainee
72. Controller
73. Finance
74. Business Affairs Coordinator
75. Contract Manager
76. Consulting Accountant
77. Attorney
78. Accounting Clerk Assistant
79. Accounting Trainee
80. Key Production Assistant
81. Key Set Production Assistant
82. Key Art Production Assistant
83. Art Department Production Assistant
84. Grip Production Assistant
85. Key Grip Production Assistant
86. Back-up Set Production Assistant
87. Back-up Truck Production Assistant
88. Truck Production Assistant
89. Insert Unit Location Manager
90. Character Technical Supervisor
91. Production Designer
92. Script Researcher
93. Researcher
94. Research Assistant
95. Head of Programming
96. Head of Research
97. Broadcast Producer
98. Publicist
99. Travel Coordinator
100. Data Management Technician
101. Director of Operations
102. General Manager
103. Human Resources
104. Administration
105. Executive Assistant
106. Executive Producer's Assistant
107. Production Secretary
108. Production Office Coordinator
109. Production Consultant
110. Consulting Producer
111. Executive Consultant
112. Senior Executive Consultant
113. Production Consultant
114. Script Researcher
115. Script Researcher
116. Researcher
117. Script Researcher
118. Writers' Production
119. Assistant Extras Casting
120. Back-up Set Production Assistant
121. Back-up Truck Production Assistant
122. Key Production Assistant
123. Key Set Production Assistant
124. Key Art Production Assistant
125. Character Technical Supervisor
126. Casting Consultant
127. Casting Researcher
128. Casting Assistant
129. Casting Associate
130. Assistant Extras Casting
131. Extras Casting
132. Extras Casting Assistant
133. Extras Casting Coordinator
134. Additional Production Assistant
135. Back-up Set Production Assistant
136. Back-up Truck Production Assistant
137. Grip Production Assistant
138. Truck Production Assistant
139. Production Runner
140. Production Driver
141. Assistant Accountant
142. First Assistant Accountant
143. Second Assistant Accountant
144. Accounting Supervisor
145. Accounting Clerk Assistant
146. Accounting Trainee
147. [Any other Production roles alphabetical]
148. Other

### Sound (Stage 1)
1.  Original Music Composer
2.  Composer
3.  Music
4.  Music by
5.  Music Composed by
6.  Music Score
7.  Original Score Composed by
8.  Original Score Music
9.  Original Score
10. Original Music
11. Additional Soundtrack
12. Main Title Theme Composer
13. Music Arranger
14. Orchestrator
15. Orchestration
16. Songs

### Sound (Stage 2)
1.  Music Score Producer
2.  Music Producer
3.  Music Editor
4.  Supervising Music Editor
5.  Music Director
6.  Music Coordinator
7.  Music Supervisor
8.  Music Co-Supervisor
9.  Additional Music Supervisor
10. Assistant Music Supervisor
11. Music Supervision Assistant
12. Music Sound Design and Processing
13. Music Programmer
14. Programming
15. Keyboard Programmer
16. Conductor
17. Conducting
18. Recording Supervision
19. Theme Song Performance
20. Playback Singer
21. Vocals
22. Vocal Coach
23. Musician
24. Music Consultant
25. Scoring Mixer
26. Dolby Consultant
27. Supervising Sound Editor
28. Sound Designer
29. Sound Design
30. Supervising Sound Effects Editor
31. Sound Effects Designer
32. Sound Effects Editor
33. Effects Editor
34. Sound Editor
35. Sound Montage Associate
36. Sound Post Supervisor
37. Sound Post Production Coordinator
38. Audio Post Coordinator
39. Sound Re-Recording Mixer
40. Re-Recording Mixer
41. Re-Recording Engineer
42. Additional Sound Re-Recording Mixer
43. Additional Re-Recording Mixer
44. Sound Re-Recording Assistant
45. Sound Mix Technician
46. Sound Mixer
47. Production Sound Mixer
48. Location Sound Mixer
49. Location Sound Recordist
50. Location Sound Assistant
51. Boom Operator
52. O.B. Sound
53. Sound Recordist
54. Sound Technical Supervisor
55. Sound Engineer
56. Engineer
57. Assistant Sound Engineer
58. Sound Assistant
59. Sound Supervisor
60. Sound Director
61. Dialogue Editor
62. Supervising Dialogue Editor
63. ADR Supervisor
64. Automated Dialogue Replacement Supervisor
65. ADR Mixer
66. Joint ADR Mixer
67. ADR & Dubbing
68. ADR Editor
69. Automated Dialogue Replacement Editor
70. Supervising ADR Editor
71. Supervising Automated Dialogue Replacement Editor
72. ADR Recording Engineer
73. ADR Recordist
74. ADR Engineer
75. ADR Post Producer
76. ADR Coordinator
77. Loop Group Coordinator
78. Foley Supervisor
79. Foley
80. Foley Artist
81. Digital Foley Artist
82. Foley Editor
83. Foley Editing
84. Foley Mixer
85. Foley Recording Engineer
86. Foley Recordist
87. Assistant Foley Artist
88. Assistant Dialogue Editor
89. First Assistant Sound Editor
90. Second Assistant Sound
91. Apprentice Sound Editor
92. Assistant Sound Editor
93. Sound Effects
94. Sound Montage Associate
95. Sound Post Production Coordinator
96. Sound Assistant
97. Sound Mix Technician
98. Scoring Mixer
99. Recording Supervision
100. Utility Sound
101. Additional Production Sound Mixer
102. Additional Sound Re-Recordist
103. Additional Sound Re-Recording Mixer
104. ADR Editor wastebasket
105. Audio Post Coordinator
106. Other

## Other Departments
After Directing, Writing, and Production are fully listed (Stage 1 then Stage 2), other departments are listed. If a specific sort order isn't defined for them, they can follow standard alphabetical or default TMDB priority.
