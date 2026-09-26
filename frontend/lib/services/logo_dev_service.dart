import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'config_service.dart';

/// Logo.dev Integration Service
/// Fetches official brand & corporate logos using Logo.dev API
class LogoDevService {
  static const String _defaultPublishableKey = 'pk_POrK0vtxQ7e-rDegXEqK5w';

  /// Map brand, underwriter, and service names to their primary official web domains
  static final Map<String, String> _knownDomains = {
    // Underwriters & Insurers
    'vodacom': 'vodacom.co.za',
    'vodacom insurance': 'vodacom.co.za',
    'vodacom insurance co.': 'vodacom.co.za',
    'vodacom underwriter services': 'vodacom.co.za',
    'king price': 'kingprice.co.za',
    'king price assurance': 'kingprice.co.za',
    'discovery': 'discovery.co.za',
    'discovery insure': 'discovery.co.za',
    'discovery health': 'discovery.co.za',
    'santam': 'santam.co.za',
    'santam insurance': 'santam.co.za',
    'santam insurance ltd': 'santam.co.za',
    'sanlam': 'sanlam.co.za',
    'sanlam health': 'sanlam.co.za',
    'sanlam health care': 'sanlam.co.za',
    'momentum': 'momentum.co.za',
    'old mutual': 'oldmutual.co.za',
    'hollard': 'hollard.co.za',
    'outsurance': 'outsurance.co.za',

    // Institutions & Verification Partners
    'transunion': 'transunion.com',
    'transunion fraud screening': 'transunion.com',
    'saps': 'saps.gov.za',
    'saps police registry api': 'saps.gov.za',
    'south african police service': 'saps.gov.za',
    'dha': 'dha.gov.za',
    'home affairs': 'dha.gov.za',

    // Banking & Payment
    'capitec': 'capitecbank.co.za',
    'capitec bank': 'capitecbank.co.za',
    'standard bank': 'standardbank.co.za',
    'fnb': 'fnb.co.za',
    'first national bank': 'fnb.co.za',
    'nedbank': 'nedbank.co.za',
    'absa': 'absa.co.za',

    // Tech Brands & Manufacturers
    'apple': 'apple.com',
    'iphone': 'apple.com',
    'ipad': 'apple.com',
    'macbook': 'apple.com',
    'istore': 'apple.com',
    'istore approved replacement': 'apple.com',
    'samsung': 'samsung.com',
    'galaxy': 'samsung.com',
    'dell': 'dell.com',
    'hp': 'hp.com',
    'lenovo': 'lenovo.com',
    'huawei': 'huawei.com',
    'xiaomi': 'mi.com',
    'sony': 'sony.com',

    // Automotive
    'volkswagen': 'volkswagen.com',
    'vw': 'volkswagen.com',
    'polo': 'volkswagen.com',
    'toyota': 'toyota.com',
    'bmw': 'bmw.com',
    'mercedes': 'mercedes-benz.com',
    'ford': 'ford.com',
    'hyundai': 'hyundai.com',
  };

  /// Resolve a domain from name or query string
  static String resolveDomain(String nameOrDomain) {
    final cleaned = nameOrDomain.trim().toLowerCase();
    if (cleaned.contains('.')) {
      return cleaned;
    }

    if (_knownDomains.containsKey(cleaned)) {
      return _knownDomains[cleaned]!;
    }

    // Check partial matches
    for (final entry in _knownDomains.entries) {
      if (cleaned.contains(entry.key) || entry.key.contains(cleaned)) {
        return entry.value;
      }
    }

    // Default to adding .com
    return '$cleaned.com';
  }

  /// Construct the Logo.dev image URL
  static String getLogoUrl(
    String nameOrDomain, {
    int size = 128,
    String format = 'png',
    String? theme,
  }) {
    final domain = resolveDomain(nameOrDomain);
    String token = ConfigService.instance.logoDevPublishableKey;
    if (token.isEmpty) {
      token = _defaultPublishableKey;
    }

    var url = 'https://img.logo.dev/$domain?token=$token&size=$size&format=$format';
    if (theme != null) {
      url += '&theme=$theme';
    }
    return url;
  }
}

/// BrandLogo Widget
/// Beautiful, rounded, cached official logo component powered by Logo.dev
class BrandLogo extends StatelessWidget {
  final String? domain;
  final String? name;
  final double size;
  final double borderRadius;
  final double padding;
  final Color backgroundColor;
  final Color? borderColor;
  final IconData fallbackIcon;
  final Color fallbackIconColor;
  final bool showBorder;

  const BrandLogo({
    super.key,
    this.domain,
    this.name,
    this.size = 44.0,
    this.borderRadius = 12.0,
    this.padding = 6.0,
    this.backgroundColor = Colors.white,
    this.borderColor,
    this.fallbackIcon = Icons.shield_rounded,
    this.fallbackIconColor = const Color(0xFFFF5500),
    this.showBorder = true,
  }) : assert(domain != null || name != null, 'Either domain or name must be provided');

  @override
  Widget build(BuildContext context) {
    final logoUrl = LogoDevService.getLogoUrl(
      domain ?? name ?? 'apple.com',
      size: (size * 2).toInt().clamp(64, 400),
    );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: borderColor ?? Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2),
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Center(
            child: SizedBox(
              width: size * 0.45,
              height: size * 0.45,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: fallbackIconColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Center(
            child: Icon(
              fallbackIcon,
              color: fallbackIconColor,
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
