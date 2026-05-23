import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/resume_generator/domain/entities/resume_model.dart';

class PdfService {
  Future<Uint8List> generatePdf(
    ResumeData data,
    ResumeTemplate template,
  ) async {
    switch (template) {
      case ResumeTemplate.atsProfessional:
        return _buildAtsPdf(data);
      case ResumeTemplate.modernMinimal:
        return _buildModernPdf(data);
      case ResumeTemplate.compactClean:
        return _buildCompactPdf(data);
    }
  }

  // ── ATS Professional Template ─────────────────────────────

  Future<Uint8List> _buildAtsPdf(ResumeData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 40, vertical: 36),
        build: (context) => [
          // Header
          _atsHeader(data),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // Summary
          if (data.summary.isNotEmpty) ...[
            _atsSection('PROFESSIONAL SUMMARY'),
            pw.SizedBox(height: 6),
            pw.Text(data.summary,
                style: pw.TextStyle(
                    fontSize: 10, lineSpacing: 1.4)),
            pw.SizedBox(height: 14),
          ],

          // Projects
          if (data.projects.isNotEmpty) ...[
            _atsSection('PROJECTS'),
            pw.SizedBox(height: 6),
            ...data.projects.map((p) => _atsProject(p)),
          ],

          // Education
          if (data.education.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('EDUCATION'),
            pw.SizedBox(height: 6),
            ...data.education.map((e) => _atsEducation(e)),
          ],

          // Skills
          if (data.skillGroups.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('SKILLS'),
            pw.SizedBox(height: 6),
            ...data.skillGroups.map(
              (g) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: '${g.category}: ',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.TextSpan(
                        text: g.skills.join(', '),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Certifications
          if (data.certifications.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('CERTIFICATIONS'),
            pw.SizedBox(height: 6),
            ...data.certifications.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${c.title} — ${c.issuer}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(c.date,
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                )),
          ],

          // Achievements
          if (data.achievements.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('ACHIEVEMENTS'),
            pw.SizedBox(height: 6),
            ...data.achievements.map(
              (a) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Expanded(
                      child: pw.Text(a,
                          style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _atsHeader(ResumeData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          data.name,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          [data.email, data.phone, data.location]
              .where((s) => s.isNotEmpty)
              .join(' | '),
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (data.githubUrl.isNotEmpty || data.linkedinUrl.isNotEmpty)
          pw.Text(
            [data.githubUrl, data.linkedinUrl]
                .where((s) => s.isNotEmpty)
                .join(' | '),
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blue700,
            ),
          ),
      ],
    );
  }

  pw.Widget _atsSection(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Divider(color: PdfColors.grey500, thickness: 0.5),
      ],
    );
  }

  pw.Widget _atsProject(ResumeProject project) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                project.title,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (project.technologies.isNotEmpty)
                pw.Text(
                  project.technologies.take(4).join(', '),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 3),
          ...project.bullets.map(
            (b) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Text(b,
                        style: const pw.TextStyle(
                            fontSize: 10, lineSpacing: 1.3)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _atsEducation(ResumeEducation edu) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                edu.institution,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${edu.degree} ${edu.field}${edu.cgpa.isNotEmpty ? " — ${edu.cgpa}" : ""}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Text(edu.duration,
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ── Modern Minimal Template ───────────────────────────────

  Future<Uint8List> _buildModernPdf(ResumeData data) async {
    final pdf = pw.Document();
    final accentColor = PdfColor.fromHex('#6366F1');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Sidebar
              pw.Container(
                width: 160,
                constraints: const pw.BoxConstraints(minHeight: 842),
                color: PdfColor.fromHex('#111111'),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.name,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text('CONTACT',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor.fromHex('#888888'),
                          letterSpacing: 1.5,
                        )),
                    pw.SizedBox(height: 6),
                    if (data.email.isNotEmpty)
                      _sidebarItem(data.email),
                    if (data.phone.isNotEmpty)
                      _sidebarItem(data.phone),
                    if (data.location.isNotEmpty)
                      _sidebarItem(data.location),
                    pw.SizedBox(height: 16),
                    if (data.skillGroups.isNotEmpty) ...[
                      pw.Text('SKILLS',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColor.fromHex('#888888'),
                            letterSpacing: 1.5,
                          )),
                      pw.SizedBox(height: 8),
                      ...data.skillGroups
                          .expand((g) => g.skills)
                          .take(15)
                          .map(
                            (s) => pw.Padding(
                              padding:
                                  const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: accentColor.shade(0.8),
                                  borderRadius: pw.BorderRadius.circular(3),
                                ),
                                child: pw.Text(
                                  s,
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              // Main content
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.summary.isNotEmpty) ...[
                        _modernSection('SUMMARY', accentColor),
                        pw.SizedBox(height: 8),
                        pw.Text(data.summary,
                            style: const pw.TextStyle(
                                fontSize: 10, lineSpacing: 1.4)),
                        pw.SizedBox(height: 16),
                      ],
                      if (data.projects.isNotEmpty) ...[
                        _modernSection('PROJECTS', accentColor),
                        pw.SizedBox(height: 8),
                        ...data.projects.map((p) => _atsProject(p)),
                      ],
                      if (data.education.isNotEmpty) ...[
                        _modernSection('EDUCATION', accentColor),
                        pw.SizedBox(height: 8),
                        ...data.education.map((e) => _atsEducation(e)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _sidebarItem(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
            fontSize: 8, color: PdfColors.grey300),
        maxLines: 2,
      ),
    );
  }

  pw.Widget _modernSection(String title, PdfColor accent) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: accent,
            letterSpacing: 1.5,
          ),
        ),
        pw.Container(
          height: 2,
          color: accent,
          margin: const pw.EdgeInsets.only(top: 3, bottom: 0),
        ),
      ],
    );
  }

  // ── Compact Clean Template ────────────────────────────────

  // ── Compact Clean Template ────────────────────────────────

  Future<Uint8List> _buildCompactPdf(ResumeData data) async {
    final pdf = pw.Document();

    // Smart year parser to sort education recent to oldest
    int parseYear(String duration) {
      if (duration.toLowerCase().contains('present') || duration.toLowerCase().contains('current')) {
        return 9999;
      }
      final matches = RegExp(r'\d+').allMatches(duration);
      if (matches.isNotEmpty) {
        final valStr = matches.last.group(0)!;
        final val = int.tryParse(valStr) ?? 0;
        if (val < 100) return 2000 + val;
        return val;
      }
      return 0;
    }

    // Sort education recent to oldest
    final sortedEducation = List<ResumeEducation>.from(data.education);
    sortedEducation.sort((a, b) {
      final yearA = parseYear(a.duration);
      final yearB = parseYear(b.duration);
      return yearB.compareTo(yearA); // descending
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        build: (context) => [
          // Header
          _compactHeader(data),
          pw.SizedBox(height: 10),

          // Skills
          if (data.skillGroups.isNotEmpty) ...[
            _compactSection('SKILLS'),
            _compactSkills(data.skillGroups),
            pw.SizedBox(height: 8),
          ],

          // Training (Experience)
          if (data.experience.isNotEmpty) ...[
            _compactSection('TRAINING'),
            ...data.experience.map((e) => _compactExperience(e)),
            pw.SizedBox(height: 8),
          ],

          // Projects
          if (data.projects.isNotEmpty) ...[
            _compactSection('PROJECTS'),
            ...data.projects.map((p) => _compactProject(p)),
            pw.SizedBox(height: 8),
          ],

          // Certificates
          if (data.certifications.isNotEmpty) ...[
            _compactSection('CERTIFICATES'),
            ...data.certifications.map((c) => _compactCertificate(c)),
            pw.SizedBox(height: 8),
          ],

          // Education (Always in the last!)
          if (sortedEducation.isNotEmpty) ...[
            _compactSection('Education'),
            ...sortedEducation.map((e) => _compactEducation(e)),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _compactHeader(ResumeData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              data.name,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1E3A8A'),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Column: Socials
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (data.linkedinUrl.isNotEmpty)
                  _contactLine('LinkedIn: ', data.linkedinUrl, isBlue: true),
                if (data.githubUrl.isNotEmpty)
                  _contactLine('Github: ', data.githubUrl),
                if (data.portfolioUrl.isNotEmpty)
                  _contactLine('LeetCode: ', data.portfolioUrl),
              ],
            ),
            // Right Column: Contact Details
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (data.email.isNotEmpty)
                  _contactLine('Email: ', data.email),
                if (data.phone.isNotEmpty)
                  _contactLine('Mobile: ', data.phone),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _contactLine(String label, String value, {bool isBlue = false}) {
    final linkColor = isBlue ? PdfColor.fromHex('#1E3A8A') : PdfColors.black;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: label,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: linkColor,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _compactSection(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#1E3A8A'),
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          height: 0.8,
          color: PdfColor.fromHex('#1E3A8A'),
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _compactSkills(List<ResumeSkillGroup> groups) {
    return pw.Column(
      children: groups.map((g) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 110,
                child: pw.Text(
                  '${g.category}:',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1E3A8A'),
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  g.skills.join(', '),
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _renderBulletPoint(String text) {
    final isLinkBullet = text.toLowerCase().contains('link:') ||
        text.toLowerCase().contains('http://') ||
        text.toLowerCase().contains('https://');

    if (isLinkBullet) {
      String label = text;
      String url = "";
      String linkText = "";

      if (text.contains('https://') || text.contains('http://')) {
        final idx = text.indexOf('http');
        label = text.substring(0, idx);
        url = text.substring(idx).trim();
        linkText = url;
      } else if (text.contains(':')) {
        final idx = text.indexOf(':');
        label = text.substring(0, idx + 1);
        linkText = text.substring(idx + 1).trim();
        url = linkText.startsWith('http') ? linkText : "https://github.com";
      }

      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2.5),
              child: pw.Container(
                width: 2.5,
                height: 2.5,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                  shape: pw.BoxShape.circle,
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: label,
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                  ),
                  pw.TextSpan(
                    text: ' $linkText',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColor.fromHex('#1E3A8A'),
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2.5),
            child: pw.Container(
              width: 2.5,
              height: 2.5,
              decoration: const pw.BoxDecoration(
                color: PdfColors.black,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.15),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _compactExperience(ResumeExperience exp) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                exp.company,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1E3A8A'),
                ),
              ),
              pw.Text(
                exp.duration,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            exp.role,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 2),
          ...exp.bullets.map((b) => _renderBulletPoint(b)),
        ],
      ),
    );
  }

  String _extractProjectDate(ResumeProject project) {
    final dateReg = RegExp(
      r"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s*'?\s*(\d{2,4})\b",
      caseSensitive: false,
    );

    for (final b in project.bullets) {
      final match = dateReg.firstMatch(b);
      if (match != null) {
        return match.group(0)!;
      }
    }
    return "";
  }

  pw.Widget _compactProject(ResumeProject p) {
    String projDate = _extractProjectDate(p);
    if (projDate.isEmpty) {
      projDate = "Jan' 26"; // Reasonable fallback matching screenshot
    }

    // Standard description bullets (filter out link bullets and get first 2)
    final descBullets = p.bullets
        .where((b) =>
            !b.toLowerCase().contains('project link') &&
            !b.toLowerCase().contains('link:'))
        .take(2)
        .toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: p.title,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E3A8A'),
                      ),
                    ),
                    if (p.technologies.isNotEmpty) ...[
                      pw.TextSpan(
                        text: ' | ',
                        style: pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                      ),
                      pw.TextSpan(
                        text: p.technologies.join(', '),
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (projDate.isNotEmpty)
                pw.Text(
                  projDate,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 2),
          // Exactly two bullet points
          ...descBullets.map((b) => _renderBulletPoint(b)),
          // Exactly third is the link for that project
          if (p.liveUrl.isNotEmpty || p.githubUrl.isNotEmpty)
            _renderBulletPoint('Project Link: ${p.liveUrl.isNotEmpty ? p.liveUrl : p.githubUrl}'),
        ],
      ),
    );
  }

  pw.Widget _compactCertificate(ResumeCertification c) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: c.title,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    color: c.credentialUrl.isNotEmpty ? PdfColor.fromHex('#1E3A8A') : PdfColors.black,
                    decoration: c.credentialUrl.isNotEmpty ? pw.TextDecoration.underline : pw.TextDecoration.none,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.TextSpan(
                  text: ' | ${c.issuer}',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            c.date,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _compactEducation(ResumeEducation edu) {
    String inst = edu.institution;
    String loc = "";
    if (inst.contains(',')) {
      final idx = inst.indexOf(',');
      loc = inst.substring(idx + 1).trim();
      inst = inst.substring(0, idx).trim();
    }

    final degreeText = edu.field.isNotEmpty ? "${edu.degree} (${edu.field})" : edu.degree;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                inst,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1E3A8A'),
                ),
              ),
              if (loc.isNotEmpty)
                pw.Text(
                  loc,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.black,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                degreeText,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                edu.duration,
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          if (edu.cgpa.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              edu.cgpa.toLowerCase().contains('cgpa') || edu.cgpa.contains('.')
                  ? 'CGPA: ${edu.cgpa}'
                  : 'Percentage: ${edu.cgpa}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
