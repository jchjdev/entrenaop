int ageOnDate(DateTime birthDate, DateTime date) {
  var age = date.year - birthDate.year;
  if (date.month < birthDate.month ||
      (date.month == birthDate.month && date.day < birthDate.day)) {
    age--;
  }
  return age;
}
