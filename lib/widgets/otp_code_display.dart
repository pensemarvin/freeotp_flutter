import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/otp_provider.dart';
import '../models/otp_account.dart';

class OTPCodeDisplay extends StatefulWidget {
  final OTPAccount account;
  final TextStyle? codeStyle;
  final TextStyle? labelStyle;
  final bool showProgress;
  final bool showRemainingTime;
  final VoidCallback? onTap;

  const OTPCodeDisplay({
    Key? key,
    required this.account,
    this.codeStyle,
    this.labelStyle,
    this.showProgress = true,
    this.showRemainingTime = true,
    this.onTap,
  }) : super(key: key);

  @override
  _OTPCodeDisplayState createState() => _OTPCodeDisplayState();
}

class _OTPCodeDisplayState extends State<OTPCodeDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late String _currentCode;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _currentCode = '';
    _remainingSeconds = 0;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _updateCodeAndTime();
  }

  @override
  void didUpdateWidget(OTPCodeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.id != widget.account.id) {
      _updateCodeAndTime();
    }
  }

  void _updateCodeAndTime() {
    final otpProvider = Provider.of<OTPProvider>(context, listen: false);
    
    setState(() {
      _currentCode = otpProvider.generateCode(widget.account);
      _remainingSeconds = otpProvider.getRemainingSeconds(widget.account);
    });

    // Mettre à jour le code et le temps restant chaque seconde
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateCodeAndTime();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeStyle = widget.codeStyle ??
        theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'RobotoMono',
          letterSpacing: 2.0,
        );
    final labelStyle = widget.labelStyle ?? theme.textTheme.bodySmall;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Code OTP
          Text(
            _currentCode,
            style: codeStyle,
          ),
          
          if (widget.showProgress) ...[  
            const SizedBox(height: 8),
            
            // Barre de progression
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final progress = _getProgress();
                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(theme, progress),
                  ),
                );
              },
            ),
            
            if (widget.showRemainingTime) ...[
              const SizedBox(height: 4),
              
              // Temps restant
              Text(
                'Expire dans $_remainingSeconds secondes',
                style: labelStyle,
              ),
            ],
          ],
        ],
      ),
    );
  }

  double _getProgress() {
    final otpProvider = Provider.of<OTPProvider>(context, listen: false);
    return otpProvider.getProgress(widget.account);
  }

  Color _getProgressColor(ThemeData theme, double progress) {
    if (progress > 0.9) {
      return theme.colorScheme.error;
    } else if (progress > 0.7) {
      return theme.colorScheme.primary.withOpacity(0.8);
    }
    return theme.colorScheme.primary;
  }
}
