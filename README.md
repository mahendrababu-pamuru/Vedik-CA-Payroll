# VEDIK CA Payroll

Deployment-ready payroll application covering Staff Master, attendance and leave, proportional loss of pay, loans, current-month salary advances, recovery bypass, payroll processing, bank advice, reports and Tally Prime/Edit Log journal XML.

## Run

Open `index.html`, or serve the folder with any static server. Demo data is included for immediate review. The present UI stores demo entries in browser storage; the production database structure is in `supabase/schema.sql`.

## Supabase production setup

1. Create a Supabase project and execute `supabase/schema.sql` in SQL Editor.
2. Enable Supabase Auth.
3. Add an organisation-membership table and RLS policies for every enabled table before entering real salary data.
4. Connect the screen actions to Supabase REST or `supabase-js` using only the public anon key. Never expose the service-role key.

## Payroll rules

- Gross = Basic + DA + HRA + other allowance.
- Excess leave = max(0, total leave − permitted leave).
- Loss of pay = Gross ÷ calendar days × excess leave days.
- Loan recovery = lower of monthly instalment and balance, unless bypassed.
- Salary advance is linked to a payroll month and fully recovered from that month’s salary, though the salary may be paid in the following month.
- Finalisation should freeze payroll lines, post recoveries and reduce balances transactionally.

## Free deployment

The static package can be deployed on GitHub Pages, Netlify, Vercel or Cloudflare Pages. For live Supabase data, configure authentication and RLS first.

## Authentication, vendors and roles

1. Run `supabase/schema.sql` and then `supabase/02_auth_tenancy.sql`.
2. In Supabase Authentication, create the platform-admin user for `suni.tpt@gmail.com`; do not store its password in GitHub.
3. Run `02_auth_tenancy.sql` only after that Auth user exists so it can be added to `platform_admins`.
4. Put the Supabase Project URL and publishable key in `js/config.js`. Never use a secret/service-role key there.
5. Deploy the `admin-users` Edge Function from `supabase/functions/admin-users/index.ts`. Its service-role key remains a Supabase-managed server secret.
6. Add the deployed Vercel URL to Supabase Authentication → URL Configuration → Redirect URLs.

Platform administrators can create vendors and subscriptions. Vendor administrators can invite users and assign organisation-specific roles. Tenant membership and RLS isolate each vendor's payroll records.
