# LIFORA Payment Portal

A responsive UPI payment-request manager using plain HTML/CSS/JavaScript and Supabase. The visual identity uses the supplied LIFORA emblem.

## What it includes

- Private admin sign-in (Supabase Auth).
- Create payment requests with customer, phone, purpose, amount and expiry.
- Server-stored immutable amount and UUID-based share link.
- Public checkout page with a UPI QR code and UPI-app deep link.
- Admin register with filters and manual paid marking.
- Row-level security and RPC authorization checks.

## Important payment limitation

This is a UPI payment-request and manual reconciliation tool, **not a payment gateway**. The checkout QR/deep link asks a UPI app to initiate payment. The website cannot independently confirm that money reached the bank account. Verify the credit in your bank/UPI app before using “Mark paid”. Automatic verification requires a bank/payment-provider integration and signed server-side webhooks.

## Setup

1. Create a Supabase project.
2. In Supabase Authentication, enable Email/Password and create your admin user.
3. Run the complete `supabase/schema.sql` in the Supabase SQL Editor.
4. In Authentication → Users, copy the admin user's UUID. Run the final `insert into public.payment_admins...` statement in the SQL file with that UUID.
5. In Supabase Project Settings → API, copy the Project URL and anon/public key.
6. Open `index.html` and replace the empty values in:
   `const CONFIG={url:"",anonKey:""};`
   Use only the anon/public key. Never put a service-role key in frontend code.
7. Deploy the repository to Vercel as a static site (no build command; output directory is the repository root). Add your custom domain if desired.

## UPI recipient

The current UPI ID is set in `index.html`:
`prakashbharathi0017@oksbi`

Confirm that this UPI ID and its displayed payee name are correct before sharing payment links. Change the UPI ID in the source if the receiving account changes.

## Security notes

- Admin creation and status updates are restricted by the `payment_admins` table and checked in security-definer RPCs.
- Public checkout exposes only the payment request's name, purpose, amount, status and expiry, addressed by a random UUID.
- No direct browser write policy is granted on payment requests.
- This app does not store UPI PINs, OTPs, card details or bank credentials.
- A shared UUID link is a bearer link: anyone who receives it can view that payment request. Avoid putting sensitive personal information in the customer name or purpose fields.
- The client-side dashboard shows a computed expired state; expired links are not returned by the public checkout RPC.

## Local preview

Serve the directory with any static web server. Opening the file directly may prevent Supabase authentication or browser clipboard features from working as expected.
