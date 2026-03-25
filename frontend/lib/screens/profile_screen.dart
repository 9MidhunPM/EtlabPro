import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/student_data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'My Teachers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProfileDetailsTab(),
            _MyTeachersTab(),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailsTab extends StatelessWidget {
  const _ProfileDetailsTab();

  @override
  Widget build(BuildContext context) {
    final studentData = context.watch<StudentData>();
    final profile = studentData.profile ?? {};
    final scheme = Theme.of(context).colorScheme;
    final name = profile['full_name'] ?? '—';
    final shrNo = studentData.shrNumber ?? profile['roll_number'] ?? '';

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Avatar header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withAlpha(180)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white.withAlpha(40),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: scheme.onPrimary),
                ),
              ),
              const SizedBox(height: 12),
              Text(name, style: TextStyle(color: scheme.onPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${profile['programme'] ?? ''} • ${profile['department'] ?? ''}',
                style: TextStyle(color: scheme.onPrimary.withAlpha(200), fontSize: 13),
              ),
              Text(
                'SHR No: $shrNo',
                style: TextStyle(color: scheme.onPrimary.withAlpha(180), fontSize: 12),
              ),
            ],
          ),
        ),
        _section(context, 'Personal', Icons.person_outline, [
          _row('Date of Birth',   profile['date_of_birth']),
          _row('Gender',          profile['gender']),
          _row('Blood Group',     profile['blood_group']),
          _row('Nationality',     profile['nationality']),
          _row('Religion',        profile['religion']),
          _row('Community',       profile['community']),
          _row('Caste',           profile['caste']),
          _row('Mother Tongue',   profile['mother_tongue']),
          _row('Place of Birth',  profile['place_of_birth']),
        ]),
        _section(context, 'Academic', Icons.school_outlined, [
          _row('Admission No.',   profile['admission_number']),
          _row('Semester',        profile['semester']),
          _row('Academic Year',   profile['academic_year']),
          _row('Date of Admission', profile['date_of_admission']),
          _row('Admission Quota', profile['admission_quota']),
          _row('Admission Type',  profile['admission_type']),
          _row('Reg No.',         profile['regno']),
          _row('ABC ID',          profile['abc_id']),
          _row('Aadhaar No.',     profile['aadhaar_no']),
        ]),
        _section(context, 'Contact', Icons.contact_phone_outlined, [
          _row('Email',           profile['email']),
          _row('Phone',           profile['phone']),
          _row('Address',         profile['address']),
          _row('Street',          profile['street']),
          _row('District',        profile['district']),
          _row('State',           profile['state']),
          _row('PIN Code',        profile['pin_code']),
          _row('Boarding Point',  profile['boarding_point']),
          _row('Hosteler',        profile['is_hosteler']),
        ]),
        _section(context, 'Family', Icons.people_outline, [
          _row('Father / Guardian', profile['guardian_name']),
          _row('Father Phone',    profile['guardian_phone']),
          _row('Father Occupation', profile['father_occupation']),
          _row('Father Education', profile['father_education']),
          _row('Mother Name',     profile['mother_name']),
          _row('Mother Phone',    profile['mother_phone']),
          _row('Mother Occupation', profile['mother_occupation']),
          _row('Mother Education', profile['mother_education']),
          _row('Annual Income',   profile['annual_income']),
        ]),
        _section(context, 'Bank', Icons.account_balance_outlined, [
          _row('Bank Name',       profile['bank_name']),
          _row('Account No.',     profile['bank_account_no']),
          _row('IFSC',            profile['bank_ifsc']),
          _row('Fee Concession',  profile['fee_concession']),
        ]),
        _section(context, 'Qualifications', Icons.workspace_premium_outlined, [
          _row('Plus Two Board',  profile['plus_two_board']),
          _row('Last School',     profile['last_school']),
          _row('HSS Year',        profile['hss_year']),
          _row('SSLC %',          profile['sslc_pct']),
          _row('SSLC Year',       profile['sslc_year']),
          _row('Plus Two %',      profile['plus_two_overall_pct']),
          _row('Maths Mark',      profile['maths_mark']),
          _row('Physics Mark',    profile['physics_mark']),
          _row('Chemistry Mark',  profile['chemistry_mark']),
          _row('PCM %',           profile['pcm_pct']),
          _row('Entrance Rank',   profile['entrance_rank']),
          _row('Entrance Score',  profile['entrance_exam_score']),
        ]),
      ],
    );
  }

  Widget _section(BuildContext context, String title, IconData icon, List<_InfoRow> children) {
    final nonEmpty = children.where((w) => w.value != null && w.value!.toString().isNotEmpty).toList();
    if (nonEmpty.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: scheme.primary)),
              ],
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withAlpha(30)),
            ),
            child: Column(
              children: nonEmpty.asMap().entries.map((e) => Column(
                children: [
                  e.value,
                  if (e.key < nonEmpty.length - 1)
                    Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant.withAlpha(80)),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  _InfoRow _row(String label, dynamic value) => _InfoRow(label: label, value: value?.toString());
}

class _MyTeachersTab extends StatelessWidget {
  const _MyTeachersTab();

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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
            const SizedBox(height: 12),
            Text('No teachers found', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final sortedTeachers = teacherSubjects.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: sortedTeachers.length,
      itemBuilder: (context, index) {
        final teacherName = sortedTeachers[index];
        final subjects = teacherSubjects[teacherName]!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.primary.withAlpha(30)),
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
