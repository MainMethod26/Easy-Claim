import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'claim_stepper.dart';
import '../services/logo_dev_service.dart';

class ActiveClaimCard extends StatefulWidget {
  final String title;
  final String claimant;
  final String amount;
  final String status;
  final int currentStep;
  final ValueChanged<int>? onStepChanged;

  const ActiveClaimCard({
    super.key,
    this.title = 'Phone stolen',
    this.claimant = 'Thabo',
    this.amount = 'R4,200',
    this.status = 'Under review',
    this.currentStep = 3,
    this.onStepChanged,
  });

  @override
  State<ActiveClaimCard> createState() => _ActiveClaimCardState();
}

class _ActiveClaimCardState extends State<ActiveClaimCard> {
  late int _step;

  @override
  void initState() {
    super.initState();
    _step = widget.currentStep;
  }

  @override
  void didUpdateWidget(covariant ActiveClaimCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      _step = widget.currentStep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF030D6C).withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Active claim •" Header
          Row(
            children: [
              const Text(
                'Active claim',
                style: TextStyle(
                  color: Color(0xFFFF5500),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                width: 6.5,
                height: 6.5,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5500),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Main Claim Info Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Real brand logo from logo.dev with device badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const BrandLogo(
                    name: 'Apple',
                    size: 54.0,
                    borderRadius: 16.0,
                    padding: 8.0,
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5500),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.0),
                      ),
                      child: const Icon(
                        Icons.phone_android_rounded,
                        color: Colors.white,
                        size: 11.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14.0),

              // Title & Claimant
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      widget.claimant,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount & Status Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.amount,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 22.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E6),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SpinKitPulse(
                          color: Color(0xFFFF5500),
                          size: 14.0,
                        ),
                        const SizedBox(width: 5.5),
                        Text(
                          widget.status,
                          style: const TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28.0),

          // Horizontal 6-step progress stepper
          ClaimStepper(
            activeIndex: _step,
            onStepTapped: (index) {
              setState(() {
                _step = index;
              });
              widget.onStepChanged?.call(index);
            },
          ),
          const SizedBox(height: 4.0),
        ],
      ),
    );
  }
}
