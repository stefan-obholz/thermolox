class UserProfile {
  final String id;
  final DateTime? termsAcceptedAt;
  final DateTime? privacyAcceptedAt;
  final DateTime? marketingAcceptedAt;
  final String? locale;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? phone;
  final String? companyName;
  final String? vatId;
  final String? street;
  final String? houseNumber;
  final String? postalCode;
  final String? city;
  final String? country;
  final bool? shippingIsDifferent;
  final String? shippingStreet;
  final String? shippingHouseNumber;
  final String? shippingPostalCode;
  final String? shippingCity;
  final String? shippingCountry;
  final bool? isProfileCompleteForOrders;

  const UserProfile({
    required this.id,
    this.termsAcceptedAt,
    this.privacyAcceptedAt,
    this.marketingAcceptedAt,
    this.locale,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.phone,
    this.companyName,
    this.vatId,
    this.street,
    this.houseNumber,
    this.postalCode,
    this.city,
    this.country,
    this.shippingIsDifferent,
    this.shippingStreet,
    this.shippingHouseNumber,
    this.shippingPostalCode,
    this.shippingCity,
    this.shippingCountry,
    this.isProfileCompleteForOrders,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? map['user_id']?.toString() ?? '',
      termsAcceptedAt: _parseDate(map['terms_accepted_at']),
      privacyAcceptedAt: _parseDate(map['privacy_accepted_at']),
      marketingAcceptedAt: _parseDate(map['marketing_accepted_at']),
      locale: map['locale']?.toString(),
      firstName: map['first_name']?.toString(),
      lastName: map['last_name']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      phone: map['phone']?.toString(),
      companyName: map['company_name']?.toString(),
      vatId: map['vat_id']?.toString(),
      street: map['street']?.toString(),
      houseNumber: map['house_number']?.toString(),
      postalCode: map['postal_code']?.toString(),
      city: map['city']?.toString(),
      country: map['country']?.toString(),
      shippingIsDifferent: map['shipping_is_different'] as bool?,
      shippingStreet: map['shipping_street']?.toString(),
      shippingHouseNumber: map['shipping_house_number']?.toString(),
      shippingPostalCode: map['shipping_postal_code']?.toString(),
      shippingCity: map['shipping_city']?.toString(),
      shippingCountry: map['shipping_country']?.toString(),
      isProfileCompleteForOrders:
          map['is_profile_complete_for_orders'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
      'privacy_accepted_at': privacyAcceptedAt?.toIso8601String(),
      'marketing_accepted_at': marketingAcceptedAt?.toIso8601String(),
      'locale': locale,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'company_name': companyName,
      'vat_id': vatId,
      'street': street,
      'house_number': houseNumber,
      'postal_code': postalCode,
      'city': city,
      'country': country,
      'shipping_is_different': shippingIsDifferent,
      'shipping_street': shippingStreet,
      'shipping_house_number': shippingHouseNumber,
      'shipping_postal_code': shippingPostalCode,
      'shipping_city': shippingCity,
      'shipping_country': shippingCountry,
      'is_profile_complete_for_orders': isProfileCompleteForOrders,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
