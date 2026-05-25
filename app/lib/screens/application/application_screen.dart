import 'package:flutter/material.dart';

import '../cases/cases_screen.dart';
import '../programs/program_list_enhanced_screen.dart';
import '../schools/school_list_screen.dart';
import 'my_tracker_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class ApplicationScreen extends StatefulWidget {
  final int tabIndex;
  final ValueChanged<bool>? onSchoolSearchToolsChanged;
  final ValueChanged<bool>? onProgramSearchToolsChanged;

  const ApplicationScreen({
    super.key,
    required this.tabIndex,
    this.onSchoolSearchToolsChanged,
    this.onProgramSearchToolsChanged,
  });

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: IndexedStack(
                index: widget.tabIndex,
                children: [
                  SchoolListScreen(
                    key: SchoolListScreen.schoolListKey,
                    onSearchToolsVisibilityChanged:
                        widget.onSchoolSearchToolsChanged,
                  ),
                  ProgramListEnhancedScreen(
                    key: ProgramListEnhancedScreen.programListKey,
                    onSearchToolsVisibilityChanged:
                        widget.onProgramSearchToolsChanged,
                  ),
                  const CasesScreen(),
                  const MyTrackerScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
