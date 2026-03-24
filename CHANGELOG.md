# Changelog

## 2026-03-23

### Added — WhatsApp contact button
- "WhatsApp us" button in the final CTA section alongside the email link
- Pre-filled message: "Hi Jasper, I'm interested in learning more about SureStep Automation."
- WhatsApp link also added to footer
- Uses the official wa.me click-to-chat API

### Updated — Cookie banner now gates Calendly loading
- Calendly CSS and JS only load after user clicks "Accept"
- If cookies rejected/pending, shows a fallback message with an "Accept cookies & show calendar" button
- Fully GDPR-compliant: no third-party scripts fire without consent

### Added — GDPR cookie consent banner
- Fixed bottom banner with Accept/Reject buttons
- Persists choice in localStorage so it only shows once
- Slides up after 800ms delay, accessible with role="dialog"
- Responsive layout (stacks on mobile)

### Added — Expanded case studies section
- Replaced the 4 static "Other solutions we've built" tags with full case study blocks
- Each new case study follows the same format as the existing lead prospecting one (visual + metrics + narrative)
- **Internal operations dashboard** — logistics company consolidated 6 spreadsheets into one live dashboard, saving 8hrs/week
- **Multi-tool system integration** — e-commerce company connected Shopify, ERP, warehouse, and CRM, eliminating 15hrs/week of manual data entry
- **Automated follow-up sequences** — B2B firm recovered 35% of dropped leads with behavior-triggered sequences
- **Data extraction & classification** — accounting firm automated document sorting for 500+ docs/week at 95% accuracy
