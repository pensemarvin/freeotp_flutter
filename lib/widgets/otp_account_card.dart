import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/otp_provider.dart';
import '../models/otp_account.dart';
import 'otp_code_display.dart';

class OTPAccountCard extends StatefulWidget {
  final OTPAccount account;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const OTPAccountCard({
    Key? key,
    required this.account,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  _OTPAccountCardState createState() => _OTPAccountCardState();
}

class _OTPAccountCardState extends State<OTPAccountCard> {
  late OTPProvider _otpProvider;

  @override
  void initState() {
    super.initState();
    _otpProvider = Provider.of<OTPProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      widget.account.issuer.isNotEmpty
                          ? widget.account.issuer[0].toUpperCase()
                          : widget.account.name.isNotEmpty
                              ? widget.account.name[0].toUpperCase()
                              : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.account.issuer.isNotEmpty)
                          Text(
                            widget.account.issuer,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          widget.account.name,
                          style: widget.account.issuer.isNotEmpty
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: widget.onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 12.0),
              OTPCodeDisplay(
                account: widget.account,
                codeStyle: theme.textTheme.headlineSmall,
                labelStyle: theme.textTheme.bodySmall,
                showRemainingTime: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
