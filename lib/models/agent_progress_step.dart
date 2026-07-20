import 'package:project_manager/models/agent_profile.dart';

class AgentProgressStep {
  const AgentProgressStep({
    required this.text,
    required this.timestamp,
    this.isComplete = false,
    this.isError = false,
  });

  final String text;
  final DateTime timestamp;
  final bool isComplete;
  final bool isError;

  AgentProgressStep copyWith({
    String? text,
    bool? isComplete,
    bool? isError,
  }) {
    return AgentProgressStep(
      text: text ?? this.text,
      timestamp: timestamp,
      isComplete: isComplete ?? this.isComplete,
      isError: isError ?? this.isError,
    );
  }
}

class AgentSelfAnalysisProgress {
  const AgentSelfAnalysisProgress({
    required this.steps,
    this.partialOutput = '',
    this.isRunning = true,
  });

  final List<AgentProgressStep> steps;
  final String partialOutput;
  final bool isRunning;
}

class AgentSelfAnalysisResult {
  const AgentSelfAnalysisResult({
    this.profile,
    this.error,
    this.steps = const [],
    this.rawOutput = '',
    this.timedOut = false,
    this.idleTimedOut = false,
    this.cancelled = false,
  });

  final AgentProfile? profile;
  final String? error;
  final List<AgentProgressStep> steps;
  final String rawOutput;
  final bool timedOut;
  final bool idleTimedOut;
  final bool cancelled;

  bool get isSuccess => profile != null && error == null;
}
