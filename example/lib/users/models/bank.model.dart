class Bank {
  final String cardExpire;
  final String cardNumber;
  final String cardType;
  final String currency;
  final String iban;

  Bank({
    required this.cardExpire,
    required this.cardNumber,
    required this.cardType,
    required this.currency,
    required this.iban,
  });

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
    cardExpire: json['cardExpire'] as String,
    cardNumber: json['cardNumber'] as String,
    cardType: json['cardType'] as String,
    currency: json['currency'] as String,
    iban: json['iban'] as String,
  );

  Map<String, dynamic> toJson() => {
    'cardExpire': cardExpire,
    'cardNumber': cardNumber,
    'cardType': cardType,
    'currency': currency,
    'iban': iban,
  };
}
