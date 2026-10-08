class ProfileModel {
  final String id;
  final String name;
  final String handle;
  String get instagramHandle => handle.startsWith('@') ? handle : '@$handle';
  final String tagline;
  final String industry;
  final String brandPersonality;
  final String uniqueSellingProposition;
  final List<String> targetAudience;
  final List<String> contentGoals;
  final List<String> contentTypes;
  final String themeColorHex;
  final String avatarUrl;
  final List<String> linkedChannels;
  final List<String> defaultHashtags;
  final String? contactPhone;
  final String? contactEmail;
  final String? bio;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.handle,
    required this.tagline,
    required this.industry,
    required this.brandPersonality,
    required this.uniqueSellingProposition,
    required this.targetAudience,
    required this.contentGoals,
    required this.contentTypes,
    required this.themeColorHex,
    required this.avatarUrl,
    required this.linkedChannels,
    required this.defaultHashtags,
    this.contactPhone,
    this.contactEmail,
    this.bio,
  });

  ProfileModel copyWith({
    String? id,
    String? name,
    String? handle,
    String? tagline,
    String? industry,
    String? brandPersonality,
    String? uniqueSellingProposition,
    List<String>? targetAudience,
    List<String>? contentGoals,
    List<String>? contentTypes,
    String? themeColorHex,
    String? avatarUrl,
    List<String>? linkedChannels,
    List<String>? defaultHashtags,
    String? contactPhone,
    String? contactEmail,
    String? bio,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      tagline: tagline ?? this.tagline,
      industry: industry ?? this.industry,
      brandPersonality: brandPersonality ?? this.brandPersonality,
      uniqueSellingProposition:
          uniqueSellingProposition ?? this.uniqueSellingProposition,
      targetAudience: targetAudience ?? this.targetAudience,
      contentGoals: contentGoals ?? this.contentGoals,
      contentTypes: contentTypes ?? this.contentTypes,
      themeColorHex: themeColorHex ?? this.themeColorHex,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      linkedChannels: linkedChannels ?? this.linkedChannels,
      defaultHashtags: defaultHashtags ?? this.defaultHashtags,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      bio: bio ?? this.bio,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'handle': handle,
        'tagline': tagline,
        'industry': industry,
        'brandPersonality': brandPersonality,
        'uniqueSellingProposition': uniqueSellingProposition,
        'targetAudience': targetAudience,
        'contentGoals': contentGoals,
        'contentTypes': contentTypes,
        'themeColorHex': themeColorHex,
        'avatarUrl': avatarUrl,
        'linkedChannels': linkedChannels,
        'defaultHashtags': defaultHashtags,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'bio': bio,
      };

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? 'prof-emms',
      name: json['name'] as String? ?? 'Emms Digital Media',
      handle: json['handle'] as String? ?? '@emmsdigitalmedia',
      tagline: json['tagline'] as String? ?? 'The Content Doctor',
      industry: json['industry'] as String? ?? 'Storytelling & Video Marketing',
      brandPersonality: json['brandPersonality'] as String? ?? 'direct',
      uniqueSellingProposition: json['uniqueSellingProposition'] as String? ??
          'Turn products into emotional stories that sell',
      targetAudience: List<String>.from(json['targetAudience'] ??
          ['Brands', 'Entrepreneurs', 'Local Businesses']),
      contentGoals: List<String>.from(
          json['contentGoals'] ?? ['Lead Generation', 'Storytelling Reels']),
      contentTypes: List<String>.from(json['contentTypes'] ??
          ['60s Cash-Cow Reels', 'Behind The Scenes', '1-Sentence Hooks']),
      themeColorHex: json['themeColorHex'] as String? ?? '#FF9500',
      avatarUrl: json['avatarUrl'] as String? ?? 'assets/emms_avatar.png',
      linkedChannels: List<String>.from(json['linkedChannels'] ??
          ['instagram', 'tiktok', 'facebook', 'youtube']),
      defaultHashtags: List<String>.from(json['defaultHashtags'] ??
          ['#Storytelling', '#ContentMarketing', '#MarketingTips']),
      contactPhone: json['contactPhone'] as String? ?? '0757 638 846',
      contactEmail: json['contactEmail'] as String? ?? 'emmahsonny@gmail.com',
      bio: json['bio'] as String? ??
          'The Content Doctor / I help brands grow through content that connects. Storyteller/Filmmaker/Consultant.',
    );
  }
}

/// Pre-seeded Default Brand Profiles
const List<ProfileModel> defaultProfilesList = [
  ProfileModel(
    id: 'prof-emms',
    name: 'Emms Digital Media',
    handle: '@emmsdigitalmedia',
    tagline: 'The Content Doctor — Storytelling & High-Converting Video Ads',
    industry: 'Video Storytelling & Digital Media Marketing',
    brandPersonality: 'direct',
    uniqueSellingProposition:
        'I create engaging storytelling reels tailored to your business—crafted to grab attention and drive results.',
    targetAudience: [
      'Businesses',
      'Entrepreneurs',
      'Brands needing video ads that convert'
    ],
    contentGoals: ['Client Inbound DMs', 'Viral Reel Reach', 'High Retention'],
    contentTypes: ['60-Second Hooks', 'Story Breakdown', 'Client Highlights'],
    themeColorHex: '#FF9500', // Apple Orange
    avatarUrl: 'assets/emms_avatar.png',
    linkedChannels: ['instagram', 'tiktok', 'facebook', 'youtube'],
    defaultHashtags: [
      '#Storytelling',
      '#ContentMarketing',
      '#MarketingTips',
      '#ContentCreator',
      '#BusinessGrowth'
    ],
    contactPhone: '0757 638 846',
    contactEmail: 'emmahsonny@gmail.com',
    bio:
        'The Content Doctor / I help brands grow through content that connects. Storyteller/Filmmaker/Consultant. ✉️ emmahsonny@gmail.com DM For business 📞 0757 638 846',
  ),
  ProfileModel(
    id: 'prof-glow',
    name: 'Glow Luxe Medspa',
    handle: '@glowluxe.medspa',
    tagline: 'Clinical Elegance & Age-Defying Protocols',
    industry: 'Medspa & Advanced Skincare',
    brandPersonality: 'authoritative',
    uniqueSellingProposition:
        'Clinical skincare protocols without the discounting trap.',
    targetAudience: ['Women 28-55 seeking high-ticket skin rejuvenation'],
    contentGoals: ['Package Bookings', 'Skincare Education'],
    contentTypes: ['Protocol Walkthroughs', 'Before & After', 'Doctor Prescriptions'],
    themeColorHex: '#FF2D55', // Apple Pink/Rose
    avatarUrl:
        'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?auto=format&fit=crop&w=200&q=80',
    linkedChannels: ['tiktok', 'instagram', 'facebook', 'youtube'],
    defaultHashtags: [
      '#medspalife',
      '#aestheticmedicine',
      '#glowprotocol',
      '#skincarehacks'
    ],
    bio: 'Clinical Elegance & Age-Defying Protocols for modern aesthetic clinics.',
  ),
  ProfileModel(
    id: 'prof-hair',
    name: 'Sarah Vance Hair Studio',
    handle: '@sarahvance.hair',
    tagline: 'Master Balayage & Lived-In Blonde Specialist',
    industry: 'Hair Color & Styling',
    brandPersonality: 'trendsetting',
    uniqueSellingProposition:
        'Seamless dimensional blondes with 85% client retention.',
    targetAudience: ['Salon clients seeking lived-in maintenance cycles'],
    contentGoals: ['Balayage Bookings', 'Toner Refresh Cycles'],
    contentTypes: ['Chair Transformations', 'Toner Formulas', 'Hair Hacks'],
    themeColorHex: '#007AFF', // Apple Blue
    avatarUrl:
        'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=200&q=80',
    linkedChannels: ['tiktok', 'instagram', 'facebook'],
    defaultHashtags: [
      '#balayagespecialist',
      '#livedinblonde',
      '#hairstylistlife',
      '#salonsecrets'
    ],
    bio: 'Master Balayage & Lived-In Blonde Specialist in the heart of the city.',
  ),
];
