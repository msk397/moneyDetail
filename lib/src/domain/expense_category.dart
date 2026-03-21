enum ExpenseCategory {
  income('收入'),
  meal('餐饮'),
  shopping('购物'),
  entertainment('娱乐'),
  transport('交通'),
  payment('缴费'),
  study('学习'),
  other('其他');

  const ExpenseCategory(this.label);

  final String label;

  bool get isIncome => this == ExpenseCategory.income;

  static ExpenseCategory fromLabel(String value) {
    return ExpenseCategory.values.firstWhere(
      (item) => item.label == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}
