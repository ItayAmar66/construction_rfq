# First-Time User Experience Review — בקשות הצעת מחיר (Construction RFQ)

**Reviewer stance:** A construction company evaluating this product for the first time, exploring on their own with no onboarding call and no one to ask when something looks broken.

**Method:** Live walkthrough of the running Flutter web build (customer flow, quotes, requests, profile) at desktop (1400–3456px) and mobile (~500px window) widths, RTL Hebrew locale, using the app's demo-data mode. Not a code review — every finding below is something a user would actually see on screen.

**Severity key:** 🔴 Critical (blocks the core task / breaks trust) · 🟠 Major (confusing or unpolished, workable) · 🟡 Minor (small polish gap)

---

## 🔴 Critical

### 1. The primary "New Request" button crashes to a dead-end error screen
**Screen:** Home dashboard → **בקשת הצעת מחיר חדשה** (New RFQ Request) — the dark, filled, top-priority CTA button on the dashboard.

**Problem:** Tapping it does not open the new-request form. It replaces the whole screen with a black panel, a generic warning icon, and the text:
> אירעה שגיאה בטעינת המערכת
> נסה לרענן את הדף או להתחבר מחדש
> ("A system error occurred. Try refreshing the page or logging in again.")

There is no back button, no nav, nothing but that message — the sidebar and header are still visible but the button doesn't reveal how to escape short of a manual page refresh (which then logs the user out of the session entirely).

**Why a contractor would notice:** This is the single most important action on the whole product — it's literally what the app is for — placed front and center as the first thing a new user is invited to click. A contractor who came to try the tool, clicked the one big obvious button, and got a black screen with a scary triangle icon will not conclude "minor bug," they'll conclude "this product is broken" and leave. First impressions don't get a second chance to recover from that.

**Recommendation:** Treat this as a ship-blocker, not a polish item. Independent of root cause, the error boundary itself needs work regardless: it should never be a dead end — always include a "Back to home" action, and the error text should not tell a logged-in user to "log in again" when refreshing would just as likely land them back on the same broken screen.

### 2. Catalog navigation crashes the same way
**Screen:** Right sidebar → **קטלוג** (Catalog).

**Problem:** Same generic black error screen as above, reproduced consistently across reloads, browser sessions, and both desktop and mobile widths.

**Why a contractor would notice:** Catalog is one of five items in the primary navigation — a curious first-time user will hit this within their first minute of clicking around, not through some obscure edge case.

**Recommendation:** Same as above — fix the underlying cause, but also make the generic error screen non-fatal everywhere it can appear.

---

## 🟠 Major

### 3. Large, unbalanced empty space on request/quote detail pages (desktop)
**Screen:** Request detail (בקשות → open a request) and quote detail (הצעות → צפה בפרטי ההצעה).

**Problem:** On a normal desktop-width window, the content is squeezed into a narrow band and a large blank gap sits in the middle of the page — on the request detail screen there's a status tracker pinned to the right with roughly half the screen sitting empty to its left. It reads as a layout that was never adapted past a narrow "mobile card" width for large screens.

**Why a contractor would notice:** Construction back-office staff mostly work at a desk on a normal-size monitor, not a phone. A core screen that looks like it's rendering at 40% of the available width, with the rest left blank, reads as unfinished rather than intentional.

**Recommendation:** Cap max content width sensibly, but distribute it (e.g., two real columns of content, or center with generous but proportionate margins) rather than leaving one large dead zone.

### 4. "Compare offers" link at the bottom of quote detail looks broken, not clickable
**Screen:** Quote detail page, below the line-items table.

**Problem:** "השוואת הצעות" appears as small, centered, unstyled gray text with no button chrome, underline, icon, or hover affordance — it looks like leftover placeholder text, not a primary navigation action, even though comparing offers is presumably an important next step for a customer deciding between suppliers.

**Recommendation:** Style it as a real secondary/tertiary button consistent with the rest of the button system used elsewhere in the app (which is otherwise solid — see the Positives section).

### 5. Password field placeholder looks like a stored password
**Screen:** Login screen (all viewport sizes).

**Problem:** The password field shows `••••••••` as static hint text before the user types anything, while the email field above it shows a plain, obviously-a-placeholder email address (`you@company.co.il`). Visually the two fields don't match: the email looks empty, the password looks pre-filled. A first-time visitor's first read of the screen is "wait, is there already a password saved here?"

**Recommendation:** Use a neutral placeholder for the password field (e.g., "הסיסמה שלך" / "your password") the same way the email field does, and reserve dot-masking for text the user has actually typed.

### 6. "Demo mode" banner and its role toggle both use the same worn amber/orange accent as the app's warning color
**Screen:** Login screen, dashboard banner.

**Problem:** The demo-mode banner ("מצב הדגמה — נתונים מקומיים") uses the same beige/orange treatment as an actual warning/alert elsewhere in the product (e.g., quote-detail's "replaced item" notice). A first-time evaluator scanning quickly could misread the demo banner as something being wrong with their account rather than a neutral status indicator.

**Recommendation:** Give informational/neutral banners (like "you're in demo mode") a distinct, calmer color from actual warnings, so severity is legible at a glance.

---

## 🟡 Minor

### 7. Unrealistic-looking demo prices
**Screen:** Quotes list / quote detail.

**Problem:** Sample quotes show totals like "₪42" and "₪50" for what are described as construction material deliveries ("גימור פרו אספקה", "חומרי בניין צפון") — implausibly small numbers for the industry. This is only demo seed data, but if this is ever shown to a prospect during a sales demo, the unrealistic pricing undercuts credibility at the exact moment you're trying to build trust.

**Recommendation:** Seed demo data with prices in a believable range for the vertical (thousands, not tens, of shekels).

### 8. Dense info screens lack any lightweight visual grouping
**Screen:** Quote detail, request detail.

**Problem:** Field labels and values are all rendered at the same weight/size in tight succession (סה"כ כולל מע"מ, תנאי תשלום, אספקה, סוג ספק, תאריך בקשה, etc.) with only a horizontal rule as a section break. On a wide screen, this reads as a long, undifferentiated list rather than a scannable summary.

**Recommendation:** Light card/section grouping with a bit more breathing room between logical clusters (pricing vs. delivery vs. supplier info) would help scanability without a redesign.

---

## Positives worth preserving

These aren't findings, but they matter for calibrating the negatives above — a lot of this product is already in good shape and shouldn't be touched:

- **RTL correctness** is solid throughout: text alignment, icon mirroring (back arrows point the correct direction), form field label placement, and button order all read naturally in Hebrew — this is often where products embarrassingly fall apart, and this one doesn't.
- **Requests list, quotes list, and profile screens** are clean, well-organized, and populated with realistic-looking status chips, dates, and counts. Status pipelines (נשלח לספקים → התקבלו הצעות → הצעה אושרה → בדרך) are a nice, clear mental model for a non-technical user.
- **Empty states are handled thoughtfully** — e.g. "עדיין לא התקבלו הצעות לבקשה זו" pairs a calm icon with a one-line explanation of what to expect next, instead of a bare blank screen.
- **Mobile layout is a genuine adaptive design, not a squeezed-down desktop layout** — the right-hand sidebar nav on desktop correctly becomes a bottom tab bar on narrow viewports, with sensible icons and full-width single-column cards. This is not a trivial thing to get right in RTL and it works.
- **Typography and color are consistent** app-wide — one navy/teal/amber palette, one type scale, used the same way screen to screen. Nothing looks like it was bolted on from a different design system.

---

## Bottom line

A first-time contractor's very first click on the dashboard's main call-to-action currently ends the session in a dead, unrecoverable error screen. Everything downstream of that first click — the requests list, quotes, comparison data, profile — is in noticeably better shape: clean, RTL-correct, sensibly responsive, and functionally clear. The gap between "the parts that work are close to release-ready" and "the front door is broken" is the single biggest risk to first impressions right now.
