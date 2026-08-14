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
