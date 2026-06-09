class HebrewStrings {
  static const login = 'התחברות';
  static const register = 'הרשמה';
  static const email = 'אימייל';
  static const password = 'סיסמה';
  static const fullName = 'שם מלא / שם עסק';
  static const phone = 'טלפון';
  static const userType = 'סוג משתמש';
  static const city = 'עיר / אזור';
  static const extraNotes = 'הערות נוספות (אופציונלי)';
  static const loginButton = 'התחברות';
  static const registerButton = 'צור חשבון';
  static const goToRegister = 'אין לך חשבון? הירשם';
  static const goToLogin = 'כבר יש לך חשבון? התחבר';
  static const logout = 'התנתקות';
  static const profile = 'פרופיל';
  static const home = 'בית';
  static const back = 'חזרה';
  static const catalog = 'קטלוג';
  static const catalogMaterialsTitle = 'קטלוג חומרים';
  static const catalogCategoriesSection = 'קטגוריות';
  static const catalogProductsSection = 'מוצרים';
  static const materialRequest = 'בקשת חומרים';
  static const rfqDraftTitle = 'טיוטת בקשה';
  static const cart = rfqDraftTitle;
  static const myRequests = 'הבקשות שלי';
  static const activeOrders = 'הזמנות פעילות';
  static const receivedQuotes = 'הצעות שהתקבלו';
  static const incomingRequests = 'בקשות נכנסות';
  static const sentQuotes = 'הצעות שנשלחו';
  static const submitRequest = 'שליחה לספקים';
  static const addRfqItem = 'הוסף לבקשה';
  static const addToCart = addRfqItem;
  static const productAddedToCart = 'הפריט נוסף לבקשה';
  static String productAddedToRfq(String name) =>
      name.trim().isEmpty ? productAddedToCart : 'נוסף לבקשה: ${name.trim()}';
  static const quantity = 'כמות';
  static const notes = 'הערות';
  static const deliveryTime = 'זמן אספקה';
  static const unitPrice = 'מחיר ליחידה';
  static const totalPrice = 'סה״כ';
  static const submitQuote = 'שלח הצעת מחיר';
  static const compareQuotes = 'השוואת הצעות';
  static const quoteDetails = 'פרטי הצעה';
  static const approveQuote = 'אשר הצעה';
  static const rejectQuote = 'דחה הצעה';
  static const ordersToFulfill = 'הזמנות לביצוע';
  static const ordersHistory = 'היסטוריית הזמנות';
  static const orderDetails = 'פרטי הזמנה';
  static const markAsShipped = 'סמן כנשלח';
  static const viewQuoteDetails = 'צפה בפרטי ההצעה';
  static const emptyRfqDraft = 'טרם נוספו חומרים לבקשה';
  static const emptyCart = emptyRfqDraft;
  static const emptyRequests = 'אין בקשות עדיין';
  static const emptyRequestsHint =
      'הוסף חומרים מהקטלוג או ידנית ושלח בקשה לספקים';
  static const emptyActiveOrders = 'אין הזמנות פעילות כרגע';
  static const emptyActiveOrdersHint =
      'הזמנות מאושרות ובדרך יופיעו כאן לאחר אישור הצעה';
  static const emptySentQuotes = 'עדיין לא שלחת הצעות';
  static const emptySentQuotesHint =
      'הצעות שתשלח ללקוחות יופיעו כאן עם סיכום החומרים והסטטוס';
  static const requestConfirmationBody =
      'הבקשה נשלחה לספקים הרלוונטיים. תקבלו עדכון כשיתקבלו הצעות.';
  static const errorLoadRequests =
      'לא ניתן לטעון את הבקשות. בדוק חיבור ונסה שוב.';
  static const errorLoadActiveOrders =
      'לא ניתן לטעון הזמנות פעילות. בדוק חיבור ונסה שוב.';
  static const errorLoadSentQuotes =
      'לא ניתן לטעון הצעות שנשלחו. בדוק חיבור ונסה שוב.';
  static const emptyQuotes = 'אין הצעות עדיין';
  static const emptyIncoming = 'אין בקשות נכנסות';
  static const loading = 'טוען...';
  static const errorGeneric = 'אירעה שגיאה, נסה שוב';
  static const errorGenericHint = 'בדוק חיבור לאינטרנט ונסה שוב';
  static const confirmSubmit = 'לאשר שליחת הבקשה?';
  static const yes = 'כן';
  static const no = 'לא';
  static const requestSubmitted = 'הבקשה נשלחה בהצלחה';
  static const quoteSubmitted = 'הצעת המחיר נשלחה';
  static const save = 'שמור';
  static const cancel = 'ביטול';
  static const details = 'פרטים';
  static const category = 'קטגוריה';
  static const description = 'תיאור';
  static const unit = 'יחידת מידה';
  static const searchHint = 'חיפוש חומרים...';
  static const catalogSearchHint = 'חיפוש מוצר או מק״ט';
  static const catalogSelectorTitle = catalogMaterialsTitle;
  static const catalogSelectorSearchHint = catalogSearchHint;
  static const catalogSelectorPrompt = 'חפש או בחר קטגוריה';
  static const catalogSelectorPromptHint =
      'הקלד מילת חיפוש או בחר קטגוריה מהרשימה';
  static const catalogSelectorEmpty = 'לא נמצאו פריטים';
  static const catalogSelectorEmptyHint =
      'נסה מק״ט קצר, שם פריט אחר, או בחר קטגוריה מהרשימה · אפשר גם להוסיף פריט ידני';
  static const catalogRecentSearches = 'חיפושים אחרונים';
  static const catalogQuickCategories = 'קטגוריות אחרונות';
  static const catalogSelectedCategory = 'קטגוריה נבחרת';
  static const catalogClearCategory = 'נקה קטגוריה';
  static String catalogBrowsingCategory(String name) => 'מציג: $name';
  static const selectCatalogVariant = 'בחר גרסה';
  static const loadMore = 'טען עוד';
  static const allCategories = 'הכל';
  static const catalogAllCategoriesPicker = 'כל הקטגוריות';
  static const catalogSearchCategories = 'חיפוש קטגוריה…';
  static const catalogCategoriesEmpty = 'לא נמצאו קטגוריות';
  static String catalogCategoriesCount(int count) => '$count קטגוריות';
  static const catalogPartialImportBanner =
      'הקטלוג נטען חלקית — ייתכן שחסרים פריטים. אפשר לחפש בין מה שכבר הועלה.';
  static const sku = 'מק״ט';
  static const catalogSelectorDemo = 'דמו — בוחר קטלוג';
  static const pickFromCatalog = 'הוסף מהקטלוג';
  static const openCatalogForRfq = 'קטלוג חומרים';
  static const openCatalogForRfqHint = 'חיפוש, קטגוריות והוספה לבקשה';
  static const catalogBrowseLoading = 'טוען קטלוג…';
  static const catalogRealNotLoaded = 'הקטלוג האמיתי עדיין נטען למערכת';
  static const catalogRealNotLoadedHint =
      'אפשר לנסות שוב מאוחר יותר · או להוסיף פריט ידני לבקשה';
  static String catalogResultsSummary(int loaded, {required bool hasMore}) {
    if (loaded <= 0) return '';
    if (hasMore && loaded <= 50) return 'מציג $loaded פריטים';
    return 'נטענו $loaded פריטים';
  }
  static const addManualRfqItem = 'הוסף פריט ידני';
  static const rfqItemName = 'שם החומר / המוצר';
  static const catalogMatchedBadge = 'מהקטלוג';
  static const emptyRfqDraftHint =
      'בחר פריט מהקטלוג או הוסף פריט ידני להמשך';
  static const rfqLineNotesHint = 'הערות לפריט';
  static const rfqMaterialsTitle = 'שורות בקשה';
  static const rfqCatalogSection = 'פריטים מהקטלוג';
  static const rfqManualSection = 'פריטים ידניים';
  static const rfqRequestDetailsSection = 'פרטי הבקשה';
  static const rfqReviewSection = 'סקירה ושליחה';
  static const rfqReviewReady = 'מוכן לשליחה לספקים';
  static const rfqReviewTargetingOpen = 'הבקשה תישלח לכל הספקים הרלוונטיים';
  static const rfqBuilderStepItems = 'הוספת חומרים';
  static const rfqBuilderStepDetails = 'פרטי בקשה';
  static const rfqBuilderStepSend = 'שליחה לספקים';
  static String rfqDraftSummary(int total, int catalog, int manual) =>
      '$total שורות · $catalog מהקטלוג · $manual ידני';
  static String rfqMissingNotesHint(int count) =>
      '$count ${count == 1 ? 'שורה ללא הערות' : 'שורות ללא הערות'}';
  static const quoteExactMatch = 'מציע בדיוק את הפריט';
  static const quoteAlternative = 'מציע חלופה';
  static const quotedNameLabel = 'שם הפריט המוצע';
  static const quotedSkuLabel = 'מק״ט מוצע';
  static const exactMatchBadge = 'התאמה מדויקת';
  static const alternativeMatchBadge = 'חלופה';
  static const requestedCatalogItem = 'פריט מבוקש';
  static const supplierQuotedItem = 'הצעת הספק';
  static const requestedItemLabel = 'מבוקש';
  static const quotedItemLabel = 'מוצע';
  static const alternativeSupplierNotes = 'הערות הספק על החלופה';
  static const alternativeNoteRequired =
      'נא לתאר את החלופה בהערות לפני שליחת ההצעה';
  static const supplierMatchChoiceTitle = 'התאמת ההצעה לפריט המבוקש';
  static const supplierExactMatchHint =
      'מציעים את אותו פריט מהקטלוג שהלקוח ביקש';
  static const supplierAlternativeMatchHint =
      'מציעים פריט דומה — יש לציין שם/מק״ט והסבר קצר';

  static String alternativeApprovalWarning(int count) =>
      'בהצעה זו $count ${count == 1 ? 'פריט הוא חלופה' : 'פריטים הם חלופות'} '
      'לפריטים שביקשת מהקטלוג. ודא שההצעה מתאימה לפני האישור.';
  static const welcomeCustomer = 'שלום, מה תרצה לכלול בבקשה היום?';
  static const welcomeSupplier = 'שלום, יש בקשות חדשות להצעת מחיר';
  static const requestDetails = 'פרטי הבקשה';
  static const respondToRequest = 'הגש הצעה';
  static const availabilityNotes = 'הערות זמינות';
  static const totalQuote = 'סה״כ הצעה';
  static const productsInRequest = 'חומרים בהצעה';
  static const customerInfo = 'פרטי לקוח';
  static const requestDate = 'תאריך בקשה';
  static const status = 'סטטוס';
  static const viewQuote = 'צפה בהצעה';
  static const editProfile = 'עריכת פרופיל';
  static const demoLoginCustomer = 'התחבר כקבלן לדוגמה';
  static const demoLoginSupplier = 'התחבר כספק לדוגמה';
  static const demoModeHint =
      'מצב הדגמה — נתונים מקומיים, ללא Firebase. כולל תרחישי RFQ מוכנים.';
  static const demoModeBadge = 'מצב הדגמה';
  static const demoScenarioSection = 'תרחישי הדגמה';
  static const demoScenarioSectionHint =
      'בחר תרחיש מוכן להצגה ללקוח — השוואת הצעות או הזמנה בדרך';
  static const demoScenarioCompareTitle = 'השוואת הצעות';
  static const demoScenarioCompareHint =
      'פריט קטלוג + ידני, הצעה מדויקת מול חלופה';
  static const demoScenarioFulfilledTitle = 'הזמנה מאושרת';
  static const demoScenarioFulfilledHint = 'הזמנה שאושרה ונמצאת בדרך';
  static const demoCustomerAccountLabel = 'קבלן לדוגמה · תל אביב';
  static const demoSupplierAccountLabel = 'ספק לדוגמה · חיפוי ובלוקים';

  // Enterprise empty / loading / error copy
  static const loadingDashboard = 'טוען לוח בקרה…';
  static const loadingRequests = 'טוען בקשות…';
  static const loadingQuotes = 'טוען הצעות…';
  static const loadingCatalog = 'טוען קטלוג…';
  static const emptyIncomingHint =
      'בקשות חדשות מלקוחות יופיעו כאן לפי התאמה לקטגוריות ואזור השירות שלך.';
  static const emptyCompareHint =
      'שלחו את הבקשה לספקים או השתמשו בתרחיש ההדגמה מהלוח.';
  static const emptyRfqDraftAction = 'הוסף פריט מהקטלוג או ידנית כדי להמשיך';
  static const errorCatalogSelector = 'לא ניתן לטעון את הקטלוג כרגע';
  static const errorCatalogSearchUnavailable = 'לא ניתן לחפש בקטלוג כרגע';
  static const errorCatalogNotLoaded = 'הקטלוג עדיין לא נטען לסביבה הזו';
  static const catalogSearchErrorHint =
      'נסה שוב, הוסף פריט ידני, או בקש ממנהל המערכת לטעון קטלוג לסביבה';
  static const catalogSearchManualFallbackHint =
      'אפשר לסגור ולהוסיף פריט ידני מטיוטת הבקשה';
  static const catalogSearchDebugHint =
      'Debug: ודא ש-catalogMeta/current קיים עם variantCount>0 ו-indexes מ-deploy';
  static const retryAction = 'נסה שוב';
}
