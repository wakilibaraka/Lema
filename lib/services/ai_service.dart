import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/profile_model.dart';
import '../models/post_model.dart';

class AiService {
  final String? apiKey;
  GenerativeModel? _model;
  static AiService? _instance;

  AiService({this.apiKey}) {
    if (apiKey != null && apiKey!.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey!,
      );
    }
  }

  static AiService get instance => _instance ??= AiService();

  static Future<String> generateSinglePost({
    required String prompt,
    required ProfileModel profile,
    required String platform,
  }) async {
    final res = await instance.generatePostData(
      topic: prompt,
      profile: profile,
      platforms: [platform],
    );
    return res['caption'] as String? ?? 'Captivating storytelling reel tailored to your brand!';
  }

  static Future<List<Map<String, dynamic>>> generate7DayContentPlan({
    required String focusTopic,
    required ProfileModel profile,
  }) async {
    final posts = await instance.generate7DayPlan(
      profile: profile,
      startDate: DateTime.now(),
    );

    return posts.asMap().entries.map((entry) {
      final i = entry.key;
      final post = entry.value;
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return {
        'day': days[i % 7],
        'hook': post.hook,
        'caption': post.caption,
        'media': post.mediaUrl,
        'isVideo': post.isVideo,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> generatePostData({
    required String topic,
    required ProfileModel profile,
    required List<String> platforms,
  }) async {
    if (_model != null) {
      try {
        final prompt = '''
You are a senior social media strategist and cash-cow video producer for "${profile.name}".
Niche: ${profile.industry}
Tone: ${profile.brandPersonality}
USP: ${profile.uniqueSellingProposition}
Target Audience: ${profile.targetAudience.join(', ')}
Target Platforms: ${platforms.join(', ')}

Create a viral 60-second cash-cow video script and social post for this topic: "$topic".

Return ONLY valid JSON with keys:
{
  "title": "catchy internal title",
  "hook": "0-3s verbal and visual hook",
  "problem": "the core struggle of the customer",
  "secret": "the counter-intuitive marketing or business secret",
  "hack": "specific numbers, ROI, or quick tactic",
  "cta": "keyword CTA for DM automation",
  "caption": "complete high-converting social caption with line breaks and hashtags",
  "hashtags": ["#tag1", "#tag2", "#tag3"]
}
''';

        final res = await _model!.generateContent([Content.text(prompt)]);
        final text = res.text ?? '';
        final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final decoded = jsonDecode(clean);
        return decoded as Map<String, dynamic>;
      } catch (e) {
        // Fallback to local heuristic engine
      }
    }

    // Heuristic Local Engine (Always works 100% offline)
    return {
      'title': topic,
      'hook': 'If you are struggling with $topic in your business, stop right now. You are leaving money on the table.',
      'problem': 'Most people focus on selling features and ingredients instead of transformation and emotional outcomes.',
      'secret': 'Top 1% creators connect before they convert. Frame the result in ONE sentence, show relatable tension, and bridge to relief.',
      'hack': 'Replace 10 complicated features with 1 clear transformation statement. Conversions jump by over 40% with zero ad spend.',
      'cta': 'Comment "STORY" below and I will send you our exact word-for-word closing script! 🎬📲',
      'caption': '$topic ✨\n\nFacts tell, but stories sell. If you want your audience to remember your brand and take action, take them on an emotional journey.\n\nDM "STORY" to audit your video hooks! 🎬\n\n#Storytelling #ContentMarketing #MarketingTips #BusinessGrowth #EmmsDigitalMedia',
      'hashtags': profile.defaultHashtags,
    };
  }

  Future<List<PostModel>> generate7DayPlan({
    required ProfileModel profile,
    required DateTime startDate,
  }) async {
    final List<String> topics7 = [
      'The 3-Second Scroll Stopper: Kill The Boring Greeting',
      'The 1-Sentence Selling Framework (Results over Ingredients)',
      'Stop Selling Features, Start Selling Feelings',
      'Why Nobody Comments on Your Videos (The Opinion Ask)',
      'Behind The Scenes: Shooting High-Converting Ads with Local Brands',
      'Storytelling in Nature: The Hikers Afrique Cinematic Story',
      'Triage DMs: The Word-for-Word Closing Script',
    ];

    final sampleMedia = [
      'assets/samples/emms_storytelling_reel.mp4',
      'assets/samples/emms_story_features.mp4',
      'assets/samples/emms_post3_onesentence.png',
      'assets/samples/emms_post2_understand.png',
      'assets/samples/emms_post1_story30mins.png',
      'assets/samples/emms_storytelling_reel.mp4',
      'assets/samples/emms_story_features.mp4',
    ];

    final List<PostModel> planned = [];

    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i + 1));
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final topic = topics7[i];
      final media = sampleMedia[i];
      final isVideo = media.endsWith('.mp4');

      final gen = await generatePostData(
        topic: topic,
        profile: profile,
        platforms: profile.linkedChannels,
      );

      planned.add(PostModel(
        id: 'ai-7d-${DateTime.now().millisecondsSinceEpoch}-$i',
        title: gen['title'] ?? topic,
        hook: gen['hook'] ?? '',
        caption: gen['caption'] ?? '',
        platforms: profile.linkedChannels,
        mediaType: isVideo ? 'video' : 'image',
        mediaUrl: media,
        scheduledDate: dateStr,
        scheduledTime: i % 2 == 0 ? '17:30' : '12:15',
        status: 'scheduled',
      ));
    }

    return planned;
  }
}
