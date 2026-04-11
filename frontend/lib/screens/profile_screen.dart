import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../widgets/screen_parts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _refreshProfileWithFeedback() async {
    final data = context.read<StudentData>();
    final auth = context.read<AuthService>();
    final roll = auth.rollNumber;
    if (roll == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Session not ready. Please login again.')));
      return;
    }

    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Refreshing all data...'), duration: Duration(milliseconds: 900)));
    await data.refreshEverything(
      roll,
      username: auth.username,
      password: auth.password,
    );
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('All sections refreshed'), duration: Duration(milliseconds: 900)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/home');
            });
          }
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'My Teachers'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _ProfileDetailsTab(onRefresh: _refreshProfileWithFeedback),
              _MyTeachersTab(onRefresh: _refreshProfileWithFeedback),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailsTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _ProfileDetailsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final studentData = context.watch<StudentData>();
    final profile = studentData.profile ?? {};
    final scheme = Theme.of(context).colorScheme;
    final name = profile['full_name'] ?? '—';
    final shrNo = studentData.summary?['roll_number'] ?? studentData.shrNumber ?? profile['roll_number'] ?? '';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ScreenSectionCard(
              icon: Icons.badge_outlined,
              title: 'Student Profile',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.outline),
                ),
                child: Text(
                  'SHR: $shrNo',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.primary),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.primary.withAlpha(22),
                    child: Text(
                      name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scheme.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$name',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${profile['programme'] ?? '—'}',
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${profile['department'] ?? '—'}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        _section(context, 'Personal', Icons.person_outline, [
          _row('Date of Birth', profile['date_of_birth']),
          _row('Gender', profile['gender']),
          _row('Blood Group', profile['blood_group']),
          _row('Nationality', profile['nationality']),
          _row('Religion', profile['religion']),
          _row('Community', profile['community']),
          _row('Caste', profile['caste']),
          _row('Mother Tongue', profile['mother_tongue']),
          _row('Place of Birth', profile['place_of_birth']),
        ]),
        _section(context, 'Academic', Icons.school_outlined, [
          _row('Admission No.', profile['admission_number']),
          _row('Semester', profile['semester']),
          _row('Academic Year', profile['academic_year']),
          _row('Date of Admission', profile['date_of_admission']),
          _row('Admission Quota', profile['admission_quota']),
          _row('Admission Type', profile['admission_type']),
          _row('Reg No.', profile['regno']),
          _row('ABC ID', profile['abc_id']),
          _row('Aadhaar No.', profile['aadhaar_no']),
        ]),
        _section(context, 'Contact', Icons.contact_phone_outlined, [
          _row('Email', profile['email']),
          _row('Phone', profile['phone']),
          _row('Address', profile['address']),
          _row('Street', profile['street']),
          _row('District', profile['district']),
          _row('State', profile['state']),
          _row('PIN Code', profile['pin_code']),
          _row('Boarding Point', profile['boarding_point']),
          _row('Hosteler', profile['is_hosteler']),
        ]),
        _section(context, 'Family', Icons.people_outline, [
          _row('Father / Guardian', profile['guardian_name']),
          _row('Father Phone', profile['guardian_phone']),
          _row('Father Occupation', profile['father_occupation']),
          _row('Father Education', profile['father_education']),
          _row('Mother Name', profile['mother_name']),
          _row('Mother Phone', profile['mother_phone']),
          _row('Mother Occupation', profile['mother_occupation']),
          _row('Mother Education', profile['mother_education']),
          _row('Annual Income', profile['annual_income']),
        ]),
        _section(context, 'Bank', Icons.account_balance_outlined, [
          _row('Bank Name', profile['bank_name']),
          _row('Account No.', profile['bank_account_no']),
          _row('IFSC', profile['bank_ifsc']),
          _row('Fee Concession', profile['fee_concession']),
        ]),
        _section(context, 'Qualifications', Icons.workspace_premium_outlined, [
          _row('Plus Two Board', profile['plus_two_board']),
          _row('Last School', profile['last_school']),
          _row('HSS Year', profile['hss_year']),
          _row('SSLC %', profile['sslc_pct']),
          _row('SSLC Year', profile['sslc_year']),
          _row('Plus Two %', profile['plus_two_overall_pct']),
          _row('Maths Mark', profile['maths_mark']),
          _row('Physics Mark', profile['physics_mark']),
          _row('Chemistry Mark', profile['chemistry_mark']),
          _row('PCM %', profile['pcm_pct']),
          _row('Entrance Rank', profile['entrance_rank']),
          _row('Entrance Score', profile['entrance_exam_score']),
        ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, IconData icon, List<ScreenInfoRow> children) {
    final nonEmpty = children.where((w) => w.value.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ScreenSectionCard(
        icon: icon,
        title: title,
        child: Column(
          children: nonEmpty.asMap().entries.map((e) => Column(
            children: [
              e.value,
              if (e.key < nonEmpty.length - 1)
                Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).colorScheme.outline),
            ],
          )).toList(),
        ),
      ),
    );
  }

  ScreenInfoRow _row(String label, dynamic value) => ScreenInfoRow(label: label, value: value?.toString() ?? '');
}

class _MyTeachersTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _MyTeachersTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final timetable = context.watch<StudentData>().timetable;
    final scheme = Theme.of(context).colorScheme;

    final Map<String, String> teacherSubjects = {};

    for (final slot in timetable) {
      final t = slot['teacher_name_raw']?.toString().trim();
      final sub = slot['raw_subject_name']?.toString() ?? slot['subject_code']?.toString();
      if (t != null && t.isNotEmpty && sub != null && sub.isNotEmpty) {
        if (teacherSubjects.containsKey(t)) {
          final existing = teacherSubjects[t]!;
          if (!existing.contains(sub)) {
            teacherSubjects[t] = '$existing, $sub';
          }
        } else {
          teacherSubjects[t] = sub;
        }
      }
    }

    if (teacherSubjects.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 420,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
                    const SizedBox(height: 12),
                    Text('No teachers found', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final sortedTeachers = teacherSubjects.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: sortedTeachers.length,
        itemBuilder: (context, index) {
          final teacherName = sortedTeachers[index];
          final subjects = teacherSubjects[teacherName]!;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    teacherName.isNotEmpty ? teacherName[0].toUpperCase() : '?',
                    style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teacherName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(subjects, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
