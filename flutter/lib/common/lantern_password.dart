String? validatePermanentPassword(String password, String confirmation) {
  if (password.isEmpty) return 'Password cannot be empty';
  if (password != confirmation) return 'The confirmation is not identical.';
  return null;
}
