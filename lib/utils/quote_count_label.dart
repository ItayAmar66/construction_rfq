/// Hebrew labels for how many supplier quotes a request received.
String receivedQuotesCountLabel(int count) {
  if (count <= 0) return 'עדיין לא התקבלו הצעות';
  if (count == 1) return 'התקבלה הצעה אחת';
  return 'התקבלו $count הצעות';
}
