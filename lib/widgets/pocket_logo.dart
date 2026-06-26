import 'package:flutter/material.dart';

class PocketLogo extends StatelessWidget {
  const PocketLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
        ),
      ),
      child: Icon(
        Icons.account_balance_wallet_rounded,
        size: size * 0.52,
        color: Colors.white,
      ),
    );
  }
}
